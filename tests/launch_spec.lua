local launch = require 'launch'
local seq = require 'launch.util.seq'

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
    it.skip('opens up an output buffer for the hovered script', function ()
      launch.setup({
        scripts = {
          {name = 'test', cmd = 'echo test'},
        }
      })

      launch.open_control_panel()
      launch.start('test')
      local original_buf = vim.api.nvim_get_current_buf()
      vim.fn.setpos('.', {0, 1, 1, 0})
      vim.cmd('execute "normal \\<C-w>l"')
      assert.are_not.equal(original_buf, vim.api.nvim_get_current_buf())
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.same({ 'test' }, lines)
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
-- [ ] colors!
