require("plenary.async").tests.add_to_env()

local mock = require 'luassert.mock'
local project = require 'launch.util.project'
local result = require 'launch.util.result'
local path = require 'plenary.path'

local ide_config = require 'launch.configuration.ide'
local fs = require 'launch.util.fs'

local function fixture_path(name)
  return path.new(debug.getinfo(1, 'S').source:sub(2)):parent() / 'fixture' / name
end
local function fixture(name)
  return fs.read_file(fixture_path(name).filename):unwrap()
end

describe('configuration', function ()

  describe('ide', function ()
    it('returns an empty list if the configuration file couldnt be found', function ()
      local p = mock(project, true)
      p.launch_config.returns(result.error())

      assert.equal(0, #ide_config())
    end)

    -- TODO: more granular
    a.it('config parsing', function ()
      local p = mock(project, true)
      p.launch_config.returns(result.success(fixture_path('launch.ini')))

      local config = ide_config()

      assert.equal(2, #config)

      assert.equal('run', config[1].name)
      assert.equal('npm start', config[1].cmd)

      assert.equal('test', config[2].name)
      assert.equal('npm test', config[2].cmd)
    end)
  end)

end)
