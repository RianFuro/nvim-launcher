local path = require 'plenary.path'
local result = require 'launch.util.result'

local M = {}

local function has_project_root_indicator(path)
	return path:joinpath('.git'):is_dir() or
		path:joinpath('package.json'):exists() or
		path:joinpath('composer.json'):exists() or
		path:joinpath('.idea'):is_dir() or
		path:joinpath('.ide'):is_dir()
end

function M.guess_root()
	local path = path.new(vim.fn.getcwd())

	while path.filename ~= '/' do
		if has_project_root_indicator(path) then
			return result.success(path)
		end

		path = path:parent()
	end

	return result.error()
end

-- TODO: use result instead of nil
function M.ide_folder()
	return M.guess_root()	
		:bind(function (root)
			local ide = root / '.ide'
			if not ide:is_dir() then return result.error() end

			return result.success(ide)
		end)
end

function M.launch_config()
	return M.ide_folder()
		:bind(function (ide)
			local config = ide / 'launch.ini'
			if not config:exists() then return result.error() end

			return result.success(config)
		end)
end

return M
