local async = require 'plenary.async'
local fs = require 'launch.util.fs'
local seq = require 'launch.util.seq'
local result = require 'launch.util.result'
local project = require 'launch.util.project'

local M = {}

function M.get_scripts()
  return result.seq(function ()
    local project_root = project.guess_root():yield()
    local package_json = fs.read_file((project_root / "package.json").filename):yield()
    if vim.in_fast_event() then
      async.util.scheduler()
    end
    local decoded = vim.fn.json_decode(package_json)

    local scripts = seq.pairs(decoded.scripts)
      :map(function (pair)
        return {name = pair[1], cmd = "npm run "..pair[1], display = pair[2]}
      end)
      :collect()

    return scripts
  end):unwrap_or({})
end

return M
