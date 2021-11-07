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
            if line_nr >= x.start and line_nr < x.fin then
              x.cb()
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
