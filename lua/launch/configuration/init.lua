local M = {}

-- TODO
function M.get()
  return require 'launch.configuration.npm_package'.get_scripts()
end

return M
