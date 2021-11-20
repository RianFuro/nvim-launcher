-- TODO:
-- [ ] find out why i can't test with CursorMoved-events (maybe because it's headless?)

local async = require 'plenary.async'
local screen = require 'launch.util.screen'
local seq = require 'launch.util.seq'
local cfg = require 'launch.configuration'
local view = require 'launch.util.view'
local state = require 'launch.util.view.state'
local bindings = require 'launch.util.view.bindings_gateway'
local block = require 'launch.util.view.component'.block
local script_handle = require 'launch.script_handle'

local M = {}

local scripts = state.new {}

local function find_script(name)
  for s in seq.from(scripts):iter() do
    if s.name == name then return s end
  end

  return nil
end

function M.setup(config)
  state.set(scripts, {})
  config = config or {}
  M.extend(config.scripts or {})

  async.run(function ()
    local more_scripts = cfg.get()
    M.extend(more_scripts)
  end)
end

function M.extend(new_scripts)
  for s in seq.from(new_scripts):iter() do
    state.append(scripts, {
      name = s.name,
      cmd = s.cmd,
      display = s.display,
      is_running = false,
      bufnr = vim.api.nvim_create_buf(false, true)
    })
  end
end

local function handle_for(name)
  local script = find_script(name)
  if not script then return end
  return script_handle.new(script)
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
  return seq.from(scripts)
    :map(function (x) return x.name end)
    :map(handle_for)
    :collect()
end

function M._names()
  return seq.from(scripts):map(function (x) return x.name end):collect()
end

local view_handle = nil
function M.open_control_panel()
  if view_handle then return end

  local col, row, _, height = screen.rect_with {
    width = 200,
    height = '90%',
    valign = 'center',
    halign = 'center',
    truncate = true
  }:unwrap()

  view_handle = {
    control_panel = nil,
    output_buffer = nil
  }
  view_handle.control_panel = view.popup({
    col = col, row = row, width = 80, height = height,
    buffer_config = {
      ft = "LauncherControlPanel"
    }
  }, function (props)
    local script_entries = seq.from(props.scripts)
      :map(function (s)
        local function toggle()
          if s.is_running then
            M.stop(s.name)
          else
            M.start(s.name)
          end
        end

        local function show_output_buffer()
          if view_handle.output_buffer then
            view_handle.output_buffer:teardown()
          end

          local function goto_control_panel()
            vim.api.nvim_set_current_win(view_handle.control_panel.winnr)
          end

          view_handle.output_buffer = {
            winnr = vim.api.nvim_open_win(s.bufnr, false, {
              relative = "editor",
              width = 120,
              height = height,
              row = row,
              col = col + 82,
              border = "rounded"
            }),
            subscriptions = {
              bindings.register(s.bufnr, 'n', '<C-o>', goto_control_panel),
              bindings.register(s.bufnr, 'n', '<C-w>h', goto_control_panel)
            },
            teardown = function (self)
              if vim.api.nvim_win_is_valid(self.winnr) then
                vim.api.nvim_win_hide(self.winnr)
              end
              for unsubscribe in seq.from(self.subscriptions):iter() do
                unsubscribe()
              end
            end
          }
        end

        local function goto_output_buffer()
          if not view_handle.output_buffer then return end
          vim.api.nvim_set_current_win(view_handle.output_buffer.winnr)
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
            s.display or s.cmd)
        }
      end)
      :collect()

    return block {
      on = {
        ['q'] = function ()
          M.close_control_panel()
        end
      },
      script_entries
    }
  end, {scripts = scripts})

  vim.cmd(
    string.format(
      "autocmd WinClosed <buffer=%s> ++once :lua require 'launch'.close_control_panel()",
      view_handle.control_panel.bufnr))
end

function M.close_control_panel()
  if view_handle == nil then return end

  -- clean winclosed callback before we close so we don't recurse?
  -- this is suboptimal but needs to do for now
  vim.cmd(
    string.format(
      "au! WinClosed <buffer=%s>",
      view_handle.control_panel.bufnr))

  view_handle.control_panel.teardown()
  if view_handle.output_buffer then
    view_handle.output_buffer:teardown()
  end
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
