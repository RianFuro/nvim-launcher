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

function Seq:into_dict()
  return self:reduce(function (t, pair)
    t[pair[1]] = pair[2]
    return t
  end, {})
end

function Seq:take(n)
  local it = self.__it
  local idx = 1

  self.__it = function ()
    if idx > n then return nil end
    idx = idx + 1
    return it()
  end

  return self
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

function Seq:concat(other)
  local it = self.__it
  local other_it = other.__it
  local it_consumed = false

  self.__it = function ()
    local value

    if not it_consumed then
      value = it()
      if not value then it_consumed = true end
    end

    if not value then
      value = other_it()
    end

    return value
  end

  return self
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
  -- We're not using ipairs here so proxy objects can be iterated
  --
  local idx = 1
  ls = ls or {}

  local value_it = function ()
    local v = ls[idx]
    if v == nil then return nil end

    idx = idx + 1
    return v
  end

  return M.from_iter(value_it)
end

local function resolve_pairs_func(t)
  local meta = getmetatable(t)
  if type(meta) == 'table' and meta.__pairs then
    return meta.__pairs
  end

  return pairs
end

function M.keys(m)
  local iter_func = resolve_pairs_func(m)
  local it, _, k = iter_func(m)
  local value_it = function ()
    k = it(m, k)
    return k
  end

  return M.from_iter(value_it)
end

function M.values(m)
  local iter_func = resolve_pairs_func(m)
  local it, _, k = iter_func(m)
  local value

  local value_it = function ()
    k, value = it(m, k)
    return value
  end

  return M.from_iter(value_it)
end

function M.pairs(m)
  local iter_func = resolve_pairs_func(m)
  local it, _, k = iter_func(m)
  local value

  local value_it = function ()
    k, value = it(m, k)
    if k == nil then return nil end
    -- we return a table here to stay compatible with the rest of the api.
    -- expecting variable returns from the iterator functions makes life very complicated.
    return {k, value}
  end

  return M.from_iter(value_it)
end

function M.reverse(ls)
  ls = ls or {}
  local idx = #ls

  local value_it = function ()
    local v = ls[idx]
    if v == nil then return nil end

    idx = idx - 1
    return v
  end

  return M.from_iter(value_it)
end

function M.from_iter(it)
  return setmetatable({ __it = it }, {
    __index = Seq,
    __add = Seq.concat
  })
end

function M.rep(val)
  return M.from_iter(function ()
    return val
  end)
end

setmetatable(M, {
  __call = function (self, iter)
    return self.from_iter(iter)
  end,
  __index = Seq
})

return M
