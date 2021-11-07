local seq = require 'launch.util.seq'

local M = {}

local function parse_option(item)
  local field, rest = item:match('^([%w|_]+)%s*(.*)$')
  local value
  if rest ~= '' then
    value = rest:match('=%s*(.+)')
  else
    value = true
  end
  return {field, value}
end

function M.parse(content)
  return seq.from_iter(content:gmatch("[^\r\n]+"))
    :filter(function (l) return l ~= '' end)
    :window_before(function (l) return l:match('^%[[^%[%]]+%]$') end)
    :map(function (section)
      return {
        title = section:pop():sub(2, -2),
        params = section
          :map(parse_option)
          :reduce(function (acc, cur)
            acc[cur[1]] = cur[2]
            return acc
          end, {})
      }
    end)
    :collect()
end

return M
