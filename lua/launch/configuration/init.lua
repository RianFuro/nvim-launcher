local M = {}

-- TODO
function M.get()
  return require 'launch.configuration.ide' ()
end

print(M.get)

return M
