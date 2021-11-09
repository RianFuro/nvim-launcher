-- TODO:
-- [x] configuration
-- [ ] process management
-- [/] process controller ui


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

local async = require 'plenary.async'
local seq = require 'launch.util.seq'
local cfg = require 'launch.configuration'
local view = require 'launch.util.view'
local job = require 'plenary.job'
local state = require 'launch.util.view.state'

local block = require 'launch.util.view.component'.block

local function start_job(e)
  e.output = {}

  --TODO: needs a better parser, since args can have the space quoted.
  local cmd = seq.from(vim.split(e.cmd, ' '))
  local j = job:new {
    command = cmd:pop(),
    args = cmd:collect(),
    on_stdout = vim.schedule_wrap(function (_, line)
      if line then
        state.append(e.output, line)
      end
    end),
    on_exit = function ()
      e.job = nil
    end
  }
  j:start()

  e.job = j
end

local config = nil
async.run(function ()
  config = cfg.get()

  async.util.scheduler()
  view.popup(function (props)
    local rows = seq.from(props.entries)
      :map(function (e)
        return block {
          margin_block_end = 1,
          block {
            on = {
              ["<CR>"] = function ()
                if not e.job then
                  start_job(e)
                else
                  e.job:shutdown()
                end
              end
            },
            (e.job and 'R' or 'S') .. ' ' .. e.name .. ': ' .. e.cmd,
            e.output
          }
        }
      end)
      :collect()

    return block {
      margin_block_start = 2,
      rows
    }
  end, {
    entries = config
  })
end)
