require 'tests.assertions'
local mock = require 'luassert.mock'
local fs = require 'launch.util.fs'
local result = require 'launch.util.result'
local path = require 'plenary.path'
local project = require 'launch.util.project'
local npm_package = require 'launch.configuration.npm_package'
local composer = require 'launch.configuration.composer'

describe('npm_package', function ()
  local mockFs = mock(fs, true)
  local mockProject = mock(project, true)

  before_each(function ()
    mockFs.read_file.returns(result.success [[
    {
      "scripts": {
        "start": "node server.js",
        "test": "jest"
      }
    }
    ]])
    mockProject.guess_root.returns(result.success(path.new ''))
  end)

  it('returns the entries from the `scripts` section of a `package.json` file', function ()
    local scripts = npm_package.get_scripts()
    assert.set_equal({
      {name = 'start', cmd = "npm run start", display = 'node server.js'},
      {name = 'test', cmd = "npm run test", display = 'jest'}
    }, scripts)
  end)

  it('returns an empty list if no package.json is in the project', function ()
    mockFs.read_file.returns(result.error())
    local scripts = npm_package.get_scripts()
    assert.are.same({}, scripts)
  end)

  it('returns an empty list if no project root could be determined', function ()
    mockProject.guess_root.returns(result.error())
    local scripts = npm_package.get_scripts()
    assert.are.same({}, scripts)
  end)
end)

describe('composer', function ()
  local mockFs = mock(fs, true)
  local mockProject = mock(project, true)

  before_each(function ()
    mockFs.read_file.returns(result.success [[
    {
      "scripts": {
        "pre-install-cmd": "./something.sh",
        "init": "setup.php",
        "test": ["@clearCache", "phpunit"],
        "clearCache": "rm -rf cache/*"
      },
      "script-descriptions": {
        "clearCache": "Clear view cache"
      }
    }
    ]])
    mockProject.guess_root.returns(result.success(path.new ''))
  end)

  it('returns a list of all user-defined scripts, skipping all event-based ones', function ()
    local scripts = composer.get_scripts()
    assert.set_equal({
      {name = "test", cmd = "composer run-script test", display = "@clearCache; phpunit"},
      {name = "clearCache", cmd = "composer run-script clearCache", display = "Clear view cache"}
    }, scripts)
  end)
end)
