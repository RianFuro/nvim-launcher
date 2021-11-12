local M = {}

local callback_register = {}
local funcref_register = {}

function M.register(bufno, mode, chord, cb, opts)
  local funcref = string.format('%p', cb)
  callback_register[funcref] = cb
  funcref_register[string.format('%d;%s;%s', bufno, mode, chord)] = funcref

  vim.api.nvim_buf_set_keymap(
    bufno,
    mode,
    chord,
    string.format([[<cmd>lua require 'launch.util.view.bindings_gateway'.invoke('%s')<CR>]], funcref),
    opts or {}
  )
end

function M.remove(bufno, mode, chord)
  local funcref = funcref_register[string.format('%d;%s;%s', bufno, mode, chord)]

  vim.api.nvim_buf_del_keymap(bufno, mode, chord)
  callback_register[funcref] = nil
end

function M.invoke(funcref)
  callback_register[funcref]()
end

return M
