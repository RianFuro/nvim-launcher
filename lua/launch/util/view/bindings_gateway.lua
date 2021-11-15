local M = {}

local callback_register = {}

function M.register(bufno, mode, chord, cb, opts)
  local funcref = string.format('%p', cb)
  callback_register[funcref] = cb

  vim.api.nvim_buf_set_keymap(
    bufno,
    mode,
    chord,
    string.format([[<cmd>lua require 'launch.util.view.bindings_gateway'.invoke('%s')<CR>]], funcref),
    opts or {}
  )

  return function ()
    vim.api.nvim_buf_del_keymap(bufno, mode, chord)
    callback_register[funcref] = nil
  end
end

function M.event(ev, bufno, cb)
  local funcref = string.format('%p', cb)
  callback_register[funcref] = cb
  vim.cmd(
    string.format(
      "autocmd %s <buffer=%d> :lua require 'launch.util.view.bindings_gateway'.invoke('%s')",
      ev,
      bufno,
      funcref))

  return function ()
    callback_register[funcref] = nil
  end
end

function M.invoke(funcref)
  if callback_register[funcref] then callback_register[funcref]() end
end

return M
