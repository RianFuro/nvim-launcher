-- TODO:
-- [ ] handle styling with highlights somehow

local component = require 'launch.util.view.component'
local state = require 'launch.util.view.state'
local popup = require 'plenary.popup'

local M = {}

local function view(bufno, root_component, initial_state)
  local s = state.new(initial_state or {})

  local function update()
    local data = component.render(root_component, s)
    vim.api.nvim_buf_set_lines(bufno, 0, -1, false, data)
  end

  state.subscribe(s, function ()
    update()
  end)
  
  update()

  return {
    state = s
  }
end

function M.popup(...)
  local bufnr = vim.api.nvim_create_buf(false, false)
  local winnr = popup.create(bufnr, {
    border = true,
    width = 80,
    height = 20,
    minheight = 20
  })

  local context = view(bufnr, ...)
  context.bufnr = bufnr
  context.winnr = winnr
  return context
end

return setmetatable(M, {
  __call = function (_, ...) return view(...) end
})
