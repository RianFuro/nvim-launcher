-- TODO:
-- [ ] handle styling with highlights somehow

local component = require 'launch.util.view.component'
local bindings_gateway = require 'launch.util.view.bindings_gateway'
local state = require 'launch.util.view.state'
local popup = require 'plenary.popup'
local seq = require 'launch.util.seq'

local M = {}


local function view(bufno, root_component, initial_state)
  local s = state.new(initial_state or {})
  local bindings = {}

  local function clean_callbacks()
    for chord, _ in pairs(bindings) do
      bindings_gateway.remove(bufno, 'n', chord)
    end
    bindings = {}
  end

  local function register_bindings(bs)
    for b in seq.from(bs):iter() do
      if not bindings[b.chord] then
        bindings[b.chord] = {}
        bindings_gateway.register(bufno, 'n', b.chord, function ()
          local pos = vim.fn.getpos('.')
          local line_nr = pos[2] - 1
          for _, x in ipairs(bindings[b.chord]) do
            local from, to = unpack(x.range)
            if line_nr >= from and line_nr < to then
              x.handle()
            end
          end
        end)
      end

      table.insert(bindings[b.chord], b)
    end
  end

  local function update()
    local data = component.render(root_component, s)
    clean_callbacks()
    register_bindings(data.bindings)
    --print(vim.inspect(bindings))
    data.bindings = nil
    vim.api.nvim_buf_set_lines(bufno, 0, -1, false, data)
  end

  local unsubscribe = state.subscribe(s, function ()
    if vim.in_fast_event() then
      vim.schedule(update)
    else
      update()
    end
  end)

  update()

  return {
    state = s,
    teardown = function ()
      unsubscribe()
      clean_callbacks()
    end
  }
end

function M.popup(popup_options, ...)
  local bufnr = vim.api.nvim_create_buf(false, true)
  local winnr = popup.create(bufnr, {
    border = true,
    width = popup_options.width,
    height = popup_options.height,
    minwidth = popup_options.width,
    minheight = popup_options.height,
    row = popup_options.row,
    col = popup_options.col
  })

  local context = view(bufnr, ...)
  context.bufnr = bufnr
  context.winnr = winnr

  local _teardown = context.teardown
  context.teardown = function ()
    _teardown()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
  end

  return context
end

return setmetatable(M, {
  __call = function (_, ...) return view(...) end
})
