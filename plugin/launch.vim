if exists('g:launch_loaded') 
  finish
endif
let g:launch_loaded = 1

command! LauncherToggle lua require'launch'.toggle_control_panel()<CR>
