-- TODO:
-- return function which, when executed, returns configuration entries for .ide/launch_config.ini
-- we use a function to be able to reload if necessary

local project = require 'launch.util.project'
local result = require 'launch.util.result'
local seq = require 'launch.util.seq'
local ini = require 'launch.util.ini_parser'
local fs = require 'launch.util.fs'

local function load(path)
	return fs.read_file(path.filename)
		:map(ini.parse)
end

local function parse(item)
	return {
		name = item.title,
		cmd = item.params.cmd,
		working_directory = item.params.working_directory,
		source = 'ide'
	}
end

return function ()
  return seq.from(
			project.launch_config()
				:bind(load)
				:unwrap_or({})
		)
		:map(parse)
		:collect()
end
