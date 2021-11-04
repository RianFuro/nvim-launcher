local async = require 'plenary.async'
local uv = async.uv
local result = require 'launch.util.result'
local M = {}

function M.read_file(path)
  return result.seq(function ()
    local fd = result(uv.fs_open(path, "r", 438)):yield()
    local stat = result(uv.fs_fstat(fd)):yield()
    local data = result(uv.fs_read(fd, stat.size, 0)):yield()
    result(uv.fs_close(fd)):yield()
    return data
  end)
end

return M
