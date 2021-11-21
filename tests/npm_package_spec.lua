local mock = require 'luassert.mock'
local fs = require 'launch.util.fs'
local result = require 'launch.util.result'
local path = require 'plenary.path'
local project = require 'launch.util.project'
local npm_package = require 'launch.configuration.npm_package'
local composer = require 'launch.configuration.composer'

local function table_findkeyof(t, element)
    -- Return the key k of the given element in table t, so that t[k] == element
    -- (or `nil` if element is not present within t). Note that we use our
    -- 'general' is_equal comparison for matching, so this function should
    -- handle table-type elements gracefully and consistently.
    if type(t) == "table" then
        for k, v in pairs(t) do
            if vim.deep_equal(v, element) then
                return k
            end
        end
    end
    return nil
end

local function assert_set_equal(actual, expected)
    local type_a, type_e = type(actual), type(expected)

    if type_a ~= type_e then
        assert.are.same(actual, expected)
    elseif (type_a == 'table') --[[and (type_e == 'table')]] then
        for _, v in pairs(actual) do
            if table_findkeyof(expected, v) == nil then
              -- assert just to get the nice error message
              assert.are.same(actual, expected)
            end
        end
        for _, v in pairs(expected) do
            if table_findkeyof(actual, v) == nil then
              -- assert just to get the nice error message
              assert.are.same(actual, expected)
            end
        end
        return true

    elseif actual ~= expected then
        return false
    end

    return true
end


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
    assert_set_equal({
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
    assert_set_equal({
      {name = "test", cmd = "composer run-script test", display = "@clearCache; phpunit"},
      {name = "clearCache", cmd = "composer run-script clearCache", display = "Clear view cache"}
    }, scripts)
  end)
end)
