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

local async = require 'plenary.async'
local float = require 'plenary.window.float'
local cfg = require 'launch.configuration'

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
  local config = cfg.get()

  configuration = config
  loading = false

  async.util.scheduler()
  open_window()
end)


