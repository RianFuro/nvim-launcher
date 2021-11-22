local assert = require('luassert.assert')

local function set_failure_message(state, message)
  if message ~= nil then
    state.failure_message = message
  end
end

local function table_findkeyof(t, element)
  if type(t) == "table" then
    for k, v in pairs(t) do
      if vim.deep_equal(v, element) then
        return k
      end
    end
  end
  return nil
end

local function set_equal(state, arguments, level)
  assert(arguments.n > 1, "Wrong number of arguments", level)
  set_failure_message(state, arguments[3])

  local actual, expected = unpack(arguments)

  if type(actual) == 'table' and type(expected) == 'table' then
    for _, v in pairs(actual) do
      if table_findkeyof(expected, v) == nil then
        return false
      end
    end
    for _, v in pairs(expected) do
      if table_findkeyof(actual, v) == nil then
        return false
      end
    end
  end

  return true
end

assert:register("assertion", "set_equal", set_equal)
