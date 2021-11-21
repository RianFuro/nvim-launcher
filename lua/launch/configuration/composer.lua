local async = require 'plenary.async'
local fs = require 'launch.util.fs'
local seq = require 'launch.util.seq'
local result = require 'launch.util.result'
local project = require 'launch.util.project'

local composer_events_hash = {
  ['pre-install-cmd'] = true,
  ['post-install-cmd'] = true,
  ['pre-update-cmd'] = true,
  ['post-update-cmd'] = true,
  ['pre-status-cmd'] = true,
  ['post-status-cmd'] = true,
  ['pre-archive-cmd'] = true,
  ['post-archive-cmd'] = true,
  ['pre-autoload-dump'] = true,
  ['post-autoload-dump'] = true,
  ['post-root-package-install'] = true,
  ['post-create-project-cmd'] = true,

  ['pre-operations-exec'] = true,

  ['pre-package-install'] = true,
  ['post-package-install'] = true,
  ['pre-package-update'] = true,
  ['post-package-update'] = true,
  ['pre-package-uninstall'] = true,
  ['post-package-uninstall'] = true,

  ['init'] = true,
  ['command'] = true,
  ['pre-file-download'] = true,
  ['post-file-download'] = true,
  ['pre-command-run'] = true,
  ['pre-pool-create'] = true
}

local M = {}

function M.get_scripts()
  return result.seq(function ()
    local project_root = project.guess_root():yield()
    local composer_json = fs.read_file((project_root / "composer.json").filename):yield()
    if vim.in_fast_event() then
      async.util.scheduler()
    end

    local decoded = vim.fn.json_decode(composer_json)
    local scripts = seq.pairs(decoded.scripts)
      :filter(function (pair)
        return composer_events_hash[pair[1]] == nil
      end)
      :map(function (pair)
        local script = decoded['script-descriptions'] and decoded['script-descriptions'][pair[1]] or pair[2]
        if type(script) == 'table' then
          script = table.concat(script, '; ')
        end

        return {name = pair[1], cmd = "composer run-script "..pair[1], display = script}
      end)
      :collect()

    return scripts
  end):unwrap_or({})
end

return M
