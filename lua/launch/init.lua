-- TODO:
-- [x] configuration
-- [ ] process management
-- [/] process controller ui


-- configuration:
-- [x] configuration parser
-- [ ] .idea importer?
-- [ ] npm importer?
-- [ ] in-memory representation

-- configuration syntax:
-- .ini syntax?

-- example:
-- [entry-name]
-- cmd = "npm run xxx"
-- working_directory = ""

local async = require 'plenary.async'
local seq = require 'launch.util.seq'
local cfg = require 'launch.configuration'
local view = require 'launch.util.view'
local state = require 'launch.util.view.state'
local bindings = require 'launch.util.view.bindings_gateway'
local job = require 'plenary.job'
local block = require 'launch.util.view.component'.block

local M = {}

local function start_job(e)
  e.output_buffer = vim.api.nvim_create_buf(false, true)
  e.term_channel = vim.api.nvim_open_term(e.output_buffer, {})
  print(e.output_buffer, e.term_channel)

  --TODO: needs a better parser, since args can have the space quoted.
  local cmd = seq.from(vim.split(e.cmd, ' '))
  local j = job:new {
    command = cmd:pop(),
    args = cmd:collect(),
    on_stdout = vim.schedule_wrap(function (_, line)
      if line and e.term_channel then
        vim.api.nvim_chan_send(e.term_channel, line..'\r\n')
      end
    end),
    on_exit = function ()
      e.job = nil
      vim.cmd(e.output_buffer .. 'bdelete')
      e.output_buffer = nil
    end
  }
  j:start()

  e.job = j
end

local app_state = state.new({})
local view_handle = nil

async.run(function ()
  app_state.config = cfg.get()
end)

local function close_control_panel()
  if view_handle.output_win then
    vim.api.nvim_win_hide(view_handle.output_win)
  end
  view_handle.teardown()
  view_handle = nil
end

local function open_control_panel()

  local column_count = vim.o.columns
  local line_count = vim.o.lines - vim.o.cmdheight
  if vim.o.laststatus ~= 0 then
    line_count = line_count - 1
  end

  -- desired width = 120
  -- desired height = 90% * max

  local width, height = 160, math.floor(line_count * 0.9)
  local width_padding = math.floor((column_count - width) / 2)
  local height_padding = math.floor((line_count - height) / 2)

  print(width, height, width_padding, height_padding)

  view_handle = view.popup({
    row = height_padding,
    col = width_padding,
    width = 40,
    height = height
  }, function (props)
    if props.config == nil then
      return block {
        "Loading..."
      }
    end

    local rows = seq.from(props.config)
      :map(function (e)
        return block {
          margin_block_end = 1,
          block {
            on = {
              ["<CR>"] = function ()
                if not e.job then
                  start_job(e)

                  bindings.register(e.output_buffer, 'n', '<C-o>', function ()
                    vim.api.nvim_set_current_win(view_handle.winnr)
                  end)
                else
                  e.job:shutdown()
                  e.job = nil
                end
              end,
              ["<C-]>"] = function ()
                if view_handle.output_win then
                  vim.api.nvim_win_hide(view_handle.output_win)
                end
                -- todo: goto buffer
                if e.output_buffer then
                  view_handle.output_win = vim.api.nvim_open_win(e.output_buffer, true, {
                    relative = "editor",
                    width = 120,
                    height = height,
                    row = height_padding,
                    col = width_padding + 40,
                    style = 'minimal',
                    border = 'double'
                  })
                  vim.api.nvim_buf_call(e.output_buffer, function () vim.cmd('normal G') end)
                end
              end,
              [" "] = function ()
                if view_handle.output_win then
                  vim.api.nvim_win_hide(view_handle.output_win)
                end

                if e.output_buffer then
                  view_handle.output_win = vim.api.nvim_open_win(e.output_buffer, false, {
                    relative = "editor",
                    width = 120,
                    height = height,
                    row = height_padding,
                    col = width_padding + 40,
                    style = 'minimal',
                    border = 'double'
                  })
                  print(view_handle.output_win)
                  vim.api.nvim_buf_call(e.output_buffer, function () vim.cmd('normal G') end)
                end
              end
            },
            (e.job and 'R' or 'S') .. ' ' .. e.name .. ': ' .. e.cmd
          }
        }
      end)
      :collect()

    return block {
      margin_block_start = 2,
      rows
    }
  end, app_state)
end

function M.toggle_control_panel()
  if not view_handle then
    open_control_panel()
  else
    close_control_panel()
  end
end

return M
