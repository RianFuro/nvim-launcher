-- TODO:
-- [x] configuration
-- [ ] process management
-- [ ] process controller ui


-- configuration:
-- [x] configuration parser
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
local project = require 'launch.util.project'
local float = require 'plenary.window.float'

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

local function load(path)
  return result.seq(function ()
    local content = fs.read_file(path.filename):yield()

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
      :collect()
  end)
end

local configuration = {}
local loading = true

--reactive?
local function open_window()
  local win, buf = float.centered()

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "test"
  })
end

async.run(function ()
  local config = seq.from(
    project.launch_config()
      :bind(load)
      :unwrap_or({})
  ):map(function (item)
    return {
      name = item.title,
      cmd = item.params.cmd,
      working_directory = item.params.working_directory,
      source = 'ide'
    }
  end):collect()

  configuration = config
  loading = false

  async.util.scheduler()
  open_window()
end)


