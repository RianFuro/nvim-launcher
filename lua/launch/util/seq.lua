local M = {}

local Seq = {}

function Seq:iter()
  return self.__it
end

function Seq:collect()
  local tbl = {}
  for v in self.__it do
    table.insert(tbl, v)
  end
  return tbl
end

function Seq:reduce(cb, init)
  local state = init
  for v in self.__it do
    state = cb(state, v)
  end
  return state
end

function Seq:pop()
  return self.__it()
end

function Seq:filter(cb)
  local it = self.__it

  self.__it = function ()
    local value
    repeat
      value = it()
      if not value then return nil end
    until cb(value)

    return value
  end

  return self
end

function Seq:map(cb)
  local it = self.__it

  self.__it = function ()
    local value = it()
    if value then
      return cb(value)
    else
      return nil
    end
  end

  return self
end

function Seq:flatten()
  local it = self.__it
  local inner_it = function () return nil end

  self.__it = function ()
    local value = inner_it()
    while not value do
      local inner = it()
      if not inner then return nil end
      inner_it = M.from(inner):iter()
      value = inner_it()
    end

    return value
  end

  return self
end

function Seq:flat_map(cb)
  return self:map(cb):flatten()
end

local function non_empty_seq(ls)
  if #ls > 0 then
    return M.from(ls)
  else
    return nil
  end
end

function Seq:window_when(cb)
  local it = self.__it
  local batch = {}

  self.__it = function ()
    for value in it do
      table.insert(batch, value)
      if cb(value) then
        local ret = M.from(batch)
        batch = {}
        return ret
      end
    end

    local ret = non_empty_seq(batch)
    batch = {}
    return ret
  end

  return self
end

function Seq:window_before(cb)
  local it = self.__it
  local batch = {}

  self.__it = function ()
    for value in it do
      if cb(value) then
        local ret = batch
        batch = {value}
        if #ret > 0 then return M.from(ret) end
      else
        table.insert(batch, value)
      end
    end

    local ret = non_empty_seq(batch)
    batch = {}
    return ret
  end

  return self
end

function M.from(ls)
  local it = ipairs(ls)
  local idx = 0

  local value_it = function ()
    local _, v = it(ls, idx)
    idx = idx + 1
    return v
  end

  return M.from_iter(value_it)
end

function M.from_iter(it)
  return setmetatable({ __it = it }, { __index = Seq })
end

setmetatable(M, {
  __call = function (self, iter)
    return self.from_iter(iter)
  end,
  __index = Seq
})

return M
