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
local float = require 'plenary.window.float'
local cfg = require 'launch.configuration'
local view = require 'launch.util.view'

local block = require 'launch.util.view.component'.block

async.run(function ()
  local config = cfg.get()

  async.util.scheduler()
  view.popup(function (props)
    local rows = seq.from(props.entries)
      :map(function (e)
        return block {
          margin_block_end = 1,
          e.name .. ': ' .. e.cmd
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
