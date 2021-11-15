-- TODO:
-- [ ] find out why i can't test with CursorMoved-events (maybe because it's headless?)

local screen = require 'launch.util.screen'
local seq = require 'launch.util.seq'
--local cfg = require 'launch.configuration'
local view = require 'launch.util.view'
local state = require 'launch.util.view.state'
local bindings = require 'launch.util.view.bindings_gateway'
local job = require 'plenary.job'
local block = require 'launch.util.view.component'.block
local popup = require 'plenary.popup'

local M = {}

local scripts = {}
local jobs = {}

function M.setup(config)
  M.extend(config.scripts or {})
end

function M.extend(new_scripts)
  for name, props in pairs(new_scripts) do
    scripts[name] = state.new {
      name = name,
      cmd = props.cmd,
      is_running = false,
      bufnr = vim.api.nvim_create_buf(false, true)
    }
  end
end

local function handle_for(name)
  local script = scripts[name]

  return setmetatable({
    start = function (self)
      if script.is_running then return end

      local cmd_parts
      if script.cmd:match('&&') then
        cmd_parts = seq.from({vim.o.shell, vim.o.shellcmdflag, script.cmd})
      else
        cmd_parts = seq.from(vim.split(script.cmd, ' '))
      end

      local term_channel = vim.api.nvim_open_term(script.bufnr, {})

      jobs[script.name] = job:new {
        command = cmd_parts:pop(),
        args = cmd_parts:collect(),
        on_stdout = vim.schedule_wrap(function (err, line)
          if err then
            print(err)
          end

          if line then
            vim.api.nvim_chan_send(term_channel, line..'\r\n')
          end
        end),
        on_exit = vim.schedule_wrap(function ()
          self.stop()
        end)
      }

      jobs[script.name]:start()
      script.is_running = true
    end,
    stop = function ()
      if not script.is_running then return end

      local j = jobs[script.name]
      -- :shutdown just blocks for a second and then continues with :_shutdown anyway
      j:_shutdown(0, 15)
      j:join()
      script.is_running = false

      local output = vim.api.nvim_buf_get_lines(script.bufnr, 0, -1, true)
      while output[#output] == '' and #output > 0 do
        output[#output] = nil
      end
      return { output = output }
    end,
    sync = function ()
      if not script.is_running then return end

      jobs[script.name]:join()
      script.is_running = false

      -- join too fast for chan_send? or maybe it's the schedule_wrap for on_stdout
      -- anyway we need to briefly wait here till all the output is available in the buffer.
      vim.cmd('sleep 10m')

      local output = vim.api.nvim_buf_get_lines(script.bufnr, 0, -1, true)
      while output[#output] == '' and #output > 0 do
        output[#output] = nil
      end
      return { output = output }
    end,
    open_output_buffer = function (mods)
      vim.cmd((mods or '') .. ' sbuffer '..script.bufnr)
    end
  }, {
    __index = function (_, k)
      return script[k]
    end
  })
end

function M.start(name)
  local handle = handle_for(name)
  handle:start()
  return handle
end

function M.stop(name)
  local handle = handle_for(name)
  handle:stop()
end

function M.restart(name)
  M.stop(name)
  return M(name)
end

function M.get(name)
  return handle_for(name)
end

function M.all()
  return seq.keys(scripts)
    :map(handle_for)
    :collect()
end

function M._names()
  return seq.keys(scripts):collect()
end

local view_handle = nil
function M.open_control_panel()
  if view_handle then return end

  -- TODO: refactor
  local output_buffer_win = nil
  local u1, u2 = nil, nil

  local col, row, _, height = screen.rect_with {
    width = 120,
    height = '90%',
    valign = 'center',
    halign = 'center'
  }:unwrap()

  view_handle = view.popup({
    col = col, row = row, width = 40, height = height
  }, function (props)
    return seq.from(props)
      :map(function (s)
        local function toggle()
          if s.is_running then
            M.stop(s.name)
          else
            M(s.name)
          end
        end

        local function show_output_buffer()
          if output_buffer_win then
            vim.api.nvim_win_hide(output_buffer_win)
            u1()
            u2()
          end

          output_buffer_win = popup.create(s.bufnr, {
            border = true,
            width = 80,
            height = height,
            minwidth = 80,
            minheight = height,
            maxwidth = 80,
            maxheight = height,
            row = row,
            col = col + 42,
            enter = false
          })

          local function goto_control_panel()
            vim.api.nvim_set_current_win(view_handle.winnr)
          end
          u1 = bindings.register(s.bufnr, 'n', '<C-o>', goto_control_panel)
          u2 = bindings.register(s.bufnr, 'n', '<C-w>h', goto_control_panel)

        end

        local function goto_output_buffer()
          if not output_buffer_win then return end
          vim.api.nvim_set_current_win(output_buffer_win)
        end

        return block {
          on = {
            ['<CR>'] = toggle,
            ['<C-]>'] = goto_output_buffer,
            ['<C-w>l'] = goto_output_buffer
          },
          -- careful with this, on_hover currently triggers for every change movement,
          -- not only when entering the block. This needs to be implemented if this get bigger than 1 line
          on_hover = show_output_buffer,
          string.format('%s [%s]: %s',
            s.is_running and '⏹' or '▶',
            s.name,
            s.cmd)
        }
      end)
      :collect()
  end, seq.values(scripts):collect())

  vim.cmd(
    string.format(
      "autocmd WinClosed <buffer=%s> ++once :lua require 'launch'.close_control_panel()",
      view_handle.bufnr))
end

function M.close_control_panel()
  if not view_handle then return end

  view_handle.teardown()
  view_handle = nil
end

function M.toggle_control_panel()
  if view_handle then
    M.close_control_panel()
  else
    M.open_control_panel()
  end
end

setmetatable(M, {
  __call = function (_, name)
    return M.start(name)
  end
})

return M
