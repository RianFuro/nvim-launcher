local f = require 'plenary.functional'
local co = coroutine
local M = {}

-- Unique constant to scope yields to the executor. See M.seq() for implementation details
local SCOPE = {}

local Result = {}

function Result:ok()
  return self[1] == nil
end

function Result:map(cb)
  if self:ok() then
    return M(nil, cb(self[2]))
  else
    return self
  end
end

function Result:map_error(cb)
	if self:ok() then
		return self
	else
		return M(cb(self[1]), self[2])
	end
end

function Result:match(cb, cbe)
	if self:ok() then
		return cb(self[2])
	else
		return cbe(self[1])
	end
end

function Result:flatten()
  if self:ok() then
    return self[2]
  else
    return self
  end
end

function Result:bind(cb)
  return self:map(cb):flatten()
end

function Result:yield()
  return co.yield(SCOPE, self)
end

function M.from(value, err)
	if value == nil then 
		return M(err or true, nil) 
	else
		return M(nil, value)
	end
end

function M.error(err)
	return M(err or true)
end

function M.success(value)
	return M(nil, value)
end

-- Sequence a batch of operations that would return results by unwrapping the result behind the scenes.
-- This works by spinning up a coroutine and yielding the results from within the routine. The executor then binds the
-- result to the next step in the routine via monadic binding, effectively shortcutting the routine if the result is
-- in error.
function M.seq(cb)
  local context = co.create(cb)

  local bind, step
  bind = function (...)
    local status = f.first(...)
    if not status then
      D(...)
    end
    if (co.status(context) == "dead") then
      local result = f.second(...)
      return M(nil, result)
    end

    local scope = f.second(...)

    -- We only handle yields that are within our "scope". This means yields always need to yield their own "scope" if
    -- this executor should handle it. (see Result:yield())
    if scope == SCOPE then
      local result = f.third(...)
      return result:bind(step)

    -- If we are within another coroutine, we assume that whatever we got yielded but doesn't concern us needs to
    -- go up the chain. So we yield and put the result back into the loop.
    -- This allows, for example, to contain the result executor in an async executor and still "await" asynchronous
    -- operations from within the result routine.
    elseif co.isyieldable() then
      return step(co.yield(select(2, ...)))

    -- If the yield is not in our "scope" but we are not in another coroutine we are effectively stuck and error out.
    else
      error("found unknown scope, but cannot yield!")
    end
  end
  step = function (...)
    return bind(co.resume(context, ...))
  end

  return step()
end

setmetatable(M, {
  __call = function (_, err, result)
    return setmetatable({err, result}, { __index = Result })
  end
})

return M
