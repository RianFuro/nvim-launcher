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
  local hover_bindings = {}

  local function clean_callbacks()
    for _, b in pairs(bindings) do
      b.remove()
    end
    bindings = {}
  end

  local function register_bindings(bs)
    for b in seq.from(bs):iter() do
      if not bindings[b.chord] then
        bindings[b.chord] = {}
        bindings[b.chord].remove = bindings_gateway.register(bufno, 'n', b.chord, function ()
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
    hover_bindings = data.hover_bindings
    data.bindings = nil
    data.hover_bindings = nil
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

  -- TODO:
  -- - [x] test drive from spike
  -- - [x] cleaning up event bindings? (better structure for sure [maybe return unsub like with observables?])
  -- - [x] use that for keybindings too!
  -- - [x] parse `on_hover` definitions from component tree like keybindings
  -- - [ ] track enter/leave to prevent firing multiple times
  bindings_gateway.event('CursorMoved', bufno, function ()
    local _, line_nr = unpack(vim.fn.getpos('.'))
    for _, b in ipairs(hover_bindings) do
      local from, to = unpack(b.range)
      if line_nr - 1 >= from and line_nr - 1 < to then
        b.handle()
      end
    end
  end)

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
