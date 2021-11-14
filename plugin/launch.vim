if exists('g:launch_loaded') 
  finish
endif
let g:launch_loaded = 1

function s:completeScriptName(lead, line, pos)
  let l:names = luaeval("require 'launch'._names()") 
  call filter(l:names, {idx, val -> val =~ '^'.a:lead})
  return l:names
endfunc

command! LauncherToggle lua require'launch'.toggle_control_panel()<CR>
command! -nargs=1 -complete=customlist,s:completeScriptName LauncherOutput lua require'launch'.get('<args>').open_output_buffer('<mods>')<CR>
