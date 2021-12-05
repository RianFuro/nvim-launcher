require 'tests.assertions'
local mock = require 'luassert.mock'
local launch = require 'launch'
local result = require 'launch.util.result'
local seq = require 'launch.util.seq'
local fs = require 'launch.util.fs'
local path = require 'plenary.path'
local project = require 'launch.util.project'

describe('launch', function ()
  it('can run a configured script', function ()
    launch.setup({
      scripts = {
        {name = 'test', cmd = 'echo Hello, World!'}
      }
    })

    local handle = launch('test')
    assert.is_true(handle.is_running)

    local result = handle:sync()
    assert.are.same({'Hello, World!'}, result.output)
  end)

  it('fills a buffer with script output', function ()
    launch.setup({
      scripts = {
        {name = 'test', cmd = 'echo Hello, World!'}
      }
    })

    local handle = launch('test')
    handle:sync()

    local lines = vim.api.nvim_buf_get_lines(handle.bufnr, 0, 1, true)
    assert.are.same({'Hello, World!'}, lines)
  end)

  it('can excute piped statements', function ()
    launch.setup({
      scripts = {
        {name = 'test', cmd = 'echo hello && echo world'}
      }
    })

    local result = launch('test'):sync()
    assert.are.same({'hello', 'world'}, result.output)
  end)

  it('can stop a script before it finishes', function ()
    launch.setup({
      scripts = {
        {name = 'test', cmd = 'sleep 10 && echo test'}
      }
    })

    local handle = launch('test')
    assert.is_true(handle.is_running)

    local result = handle:stop()
    assert.is_false(handle.is_running)
    assert.are.same({}, result.output)
  end)

  it('can return a handle by script name', function ()
    launch.setup({
      scripts = {
        {name = 'test', cmd = 'echo Hello, World!'}
      }
    })

    local handle = launch.get('test')
    assert.is_false(handle.is_running)
  end)

  it('can start a script from a handle', function ()
    launch.setup({
      scripts = {
        {name = 'test', cmd = 'echo Hello, World!'}
      }
    })

    local handle = launch.get('test')
    handle:start()
    local result = handle:sync()
    assert.are.same({'Hello, World!'}, result.output)
  end)

  it('doesnt start a script again if its already running', function ()
    launch.setup({
      scripts = {
        {name = 'test', cmd = 'sleep 10 && echo test'}
      }
    })

    local handle = launch('test')
    assert.is_true(handle.is_running)
    local bufnr = handle.bufnr

    local handle = launch('test')
    assert.is_true(handle.is_running)
    assert.equal(bufnr, handle.bufnr)
  end)

  it('does nothing when stopping a script that is not running', function ()
    launch.setup({
      scripts = {
        {name = 'test', cmd = 'echo Hello, World!'}
      }
    })

    launch.stop('test')
  end)

  it('returns a list of all configured scripts', function ()
    launch.setup({
      scripts = {
        {name = 'test', cmd = 'echo Hello, World!'},
        {name = 'other', cmd = 'echo Hello, Abyss!'}
      }
    })

    local handles = launch.all()
    assert.equal(2, #handles)
    assert.equal('test', handles[1].name)
    assert.equal('other', handles[2].name)
  end)

  it('opens the output buffer in a split', function ()
    launch.setup({
      scripts = {
        {name = 'test', cmd = 'echo Hello, World!'}
      }
    })

    local handle = launch.get('test')
    handle.open_output_buffer()

    assert.equal(handle.bufnr, vim.api.nvim_get_current_buf())
  end)

  describe('buffer', function ()
    -- tests are not completely isolated so we clean up just in case
    after_each(function ()
      launch.close_control_panel()
    end)

    it('sets the filetype correctly', function ()
      launch.open_control_panel()
      assert.equal('LauncherControlPanel', vim.o.ft)
    end)

    it('should show all configured scripts', function ()
      launch.setup({
        scripts = {
          {name = 'test', cmd = 'echo Hello, World!'},
          {name = 'other', cmd = 'echo Hello, Abyss!'}
        }
      })

      launch.open_control_panel()

      local bufnr = vim.api.nvim_get_current_buf()
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
      assert.are.same(
        {
          '▶ [test]: echo Hello, World!',
          '▶ [other]: echo Hello, Abyss!'
        },
        seq.from(lines)
          :filter(function (l) return l ~= '' end)
          :collect()
      )
    end)

    it('updates when the running state of a script is updated', function ()
      launch.setup({
        scripts = {
          {name = 'test', cmd = 'sleep 5'},
          {name = 'other', cmd = 'echo Hello, Abyss!'}
        }
      })

      launch.open_control_panel()
      local handle = launch('test')
      assert.is_true(handle.is_running)

      local bufnr = vim.api.nvim_get_current_buf()
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
      assert.are.same(
        {
          '⏹ [test]: sleep 5',
          '▶ [other]: echo Hello, Abyss!'
        },
        seq.from(lines)
          :filter(function (l) return l ~= '' end)
          :collect()
      )
    end)

    it('has keybindings to start/stop a script', function ()
      launch.setup({
        scripts = {
          {name = 'test', cmd = 'sleep 5'},
        }
      })

      launch.open_control_panel()
      local handle = launch.get('test')

      vim.fn.setpos('.', {0, 1, 1, 0})
      vim.cmd('execute "normal \\<CR>"')
      assert.is_true(handle.is_running)

      vim.cmd('execute "normal \\<CR>"')
      assert.is_false(handle.is_running)
    end)

    it('can be closed', function ()
      local original_buf = vim.api.nvim_get_current_buf()

      launch.open_control_panel()
      launch.close_control_panel()

      assert.equal(original_buf, vim.api.nvim_get_current_buf())
    end)

    it('cannot be opened twice', function ()
      launch.open_control_panel()
      local original_buf = vim.api.nvim_get_current_buf()
      launch.open_control_panel()
      assert.equal(original_buf, vim.api.nvim_get_current_buf())
    end)

    it('cleans up when the view is closed normally', function ()
      local original_buf = vim.api.nvim_get_current_buf()
      launch.open_control_panel()
      vim.cmd('q')
      assert.equal(original_buf, vim.api.nvim_get_current_buf())
      launch.open_control_panel()
      assert.are_not.equal(original_buf, vim.api.nvim_get_current_buf())
    end)

    -- does not work for some reason
    it('opens up an output buffer for the hovered script', function ()
      launch.setup({
        scripts = {
          {name = 'test', cmd = 'echo test'},
        }
      })

      local handle = launch('test')
      launch.open_control_panel()
      local original_buf = vim.api.nvim_get_current_buf()

      vim.fn.setpos('.', {0, 1, 1, 0})
      vim.cmd('doautocmd CursorMoved') -- need to fire manually, won't trigger during test
      vim.cmd('execute "normal \\<C-w>l"')

      assert.are_not.equal(original_buf, vim.api.nvim_get_current_buf())

      handle:sync()
      local lines = vim.api.nvim_buf_get_lines(0, 0, 1, false)
      assert.are.same({ 'test' }, lines)
    end)
  end)

  describe('npm_package', function ()
    local mockFs = mock(fs, true)
    local mockProject = mock(project, true)

    after_each(function ()
      mockFs.revert()
      mockProject.revert()
    end)

    describe('exists', function ()
      before_each(function ()
        mockFs.read_file.on_call_with('/path/to/project/package.json').returns(result.success [[
        {
          "scripts": {
            "start": "node server.js",
            "test": "jest"
          }
        }
        ]])
        mockProject.guess_root.returns(result.success(path.new '/path/to/project'))
        launch.setup()
      end)

      it('returns the entries from the `scripts` section of a `package.json` file', function ()
        local scripts = seq.from(launch.all())
          :map(function (x) return {name = x.name, cmd = x.cmd, display = x.display} end)
          :collect()

        assert.set_equal({
          {name = 'start', cmd = "npm run start", display = 'node server.js'},
          {name = 'test', cmd = "npm run test", display = 'jest'}
        }, scripts)
      end)
    end)

    describe('no package.json', function ()
      before_each(function ()
        mockFs.read_file.on_call_with('/path/to/project/package.json').returns(result.error())
        mockProject.guess_root.returns(result.success(path.new '/path/to/project'))
        launch.setup()
      end)

      it('returns an empty list', function ()
        local scripts = launch.all()
        assert.are.same({}, scripts)
      end)
    end)

    describe('not in project', function ()
      before_each(function ()
        mockFs.read_file.returns(result.error())
        mockProject.guess_root.returns(result.error())
        launch.setup()
      end)

      it('returns an empty list', function ()
        local scripts = launch.all()
        assert.are.same({}, scripts)
      end)
    end)

  end)

  describe('composer', function ()
    local mockFs = mock(fs, true)
    local mockProject = mock(project, true)

    after_each(function ()
      mockFs.revert()
      mockProject.revert()
    end)

    describe('exists', function ()
      before_each(function ()
        mockProject.guess_root.returns(result.success(path.new '/path/to/project'))
        mockFs.read_file.on_call_with('/path/to/project/composer.json').returns(result.success [[
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
        launch.setup()
      end)

      it('returns a list of all user-defined scripts, skipping all event-based ones', function ()
        local scripts = seq.from(launch.all())
          :map(function (x) return {name = x.name, cmd = x.cmd, display = x.display} end)
          :collect()

        assert.set_equal({
          {name = "test", cmd = "composer run-script test", display = "@clearCache; phpunit"},
          {name = "clearCache", cmd = "composer run-script clearCache", display = "Clear view cache"}
        }, scripts)
      end)
    end)
  end)
end)

-- [x] run selected launch option
-- [x] collect output of selected launch option
-- [x] fills a buffer with script output
-- [x] can stop the script before it finishes
-- [x] get running job from storage by name
-- [ ] duplicate names?
-- [x] interactive buffer to control scripts
-- [x] open interactive buffer
-- [x] buffer updates when running state changes
-- [x] update running state with keybindings
-- [ ] trying to launch unknown script should gracefully error
-- [ ] one-off scripts that are not registered?
-- [x] JobHandle object
-- [x] start from handle
-- [ ] extract view.state and call it observable
-- [x] close interactive buffer
-- [x] toggle interactive buffer
-- [x] recognize when buffer is closed normally and clean up
-- [x] open logs from api
-- [x] dont break when script has never been started
-- [x] open logs from interactive buffer
-- [x] vim command for opening logs (with autocomplete)
-- [x] colors!
-- [ ] make sure scripts are executed from the project root as working directory, even when vims cwd is in a subdirectory
-- [x] figure out why some tests just don't work (cursor moved events, switch to output buffer)
-- -> The problem is always that CursorMoved won't fire. We can manually trigger it with `doautocmd` though.
