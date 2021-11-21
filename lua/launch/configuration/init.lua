local seq = require 'launch.util.seq'

local M = {}

-- TODO
function M.get()
  return (
    seq.from(require 'launch.configuration.npm_package'.get_scripts())
    + seq.from(require 'launch.configuration.composer'.get_scripts())
  ):collect()

end

return M
