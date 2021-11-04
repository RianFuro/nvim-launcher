-- TODO:
-- [ ] configuration
-- [ ] process management
-- [ ] process controller ui


-- configuration:
-- [ ] configuration parser
-- [ ] .idea importer?
-- [ ] npm importer?
-- [ ] in-memory representation

-- configuration syntax:
-- .ini syntax?

-- example:
-- [entry-name]
-- cmd = "npm run xxx"
-- working_directory = ""

local fs = require 'launch.util.fs'
local async = require 'plenary.async'
local seq = require 'launch.util.seq'
local result = require 'launch.util.result'

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

local function load(fileName)
  assert(type(fileName) == 'string', 'Parameter "fileName" must be a string.')

  return result.seq(function ()
    local content = fs.read_file(fileName):yield()

    -- TODO: parse_option could fail if the format is invalid, so this needs to be a result.
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
  end)
end

async.run(function ()
  local result = load('/tmp/test.txt')
  D(result)
end)
