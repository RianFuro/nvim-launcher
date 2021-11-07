-- TODO:
-- [ ] proxy object
-- [ ] basically build an observable?
local M = {}

local K_SUBSCRIBERS = {}

local function publish_change(self)
  for _, cb in ipairs(self[K_SUBSCRIBERS]) do
    cb()
  end
end

function M.new(init)
  assert(type(init) == 'table', 'state needs to be a table')

  local t = {}
  local proxy = {
    [K_SUBSCRIBERS] = {}
  }

  for k, v in pairs(init) do
    if type(v) == 'table' then
      t[k] = M.new(v)
      M.subscribe(t[k], function () publish_change(proxy) end)
    else
      t[k] = v
    end
  end

  return setmetatable(proxy, {
    __index = function (_, k)
      return t[k]
    end,
    __newindex = function (self, k, v)
      t[k] = v

      publish_change(self)
    end
  })
end

function M.subscribe(state, cb)
  table.insert(state[K_SUBSCRIBERS], cb)

  return function ()
    for idx, v in ipairs(state[K_SUBSCRIBERS]) do
      if v == cb then 
        table.remove(state[K_SUBSCRIBERS], idx) 
        return
      end
    end
  end
end

return M
