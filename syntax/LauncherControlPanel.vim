if exists("b:current_syntax")
  finish
endif

syn match LauncherStart /^▶/ contained
syn match LauncherStop /^⏹/ contained
syn match LauncherScriptName /\v\[[^\]]+\]/ contained
syn region LauncherScriptEntry start=/^[▶⏹]/ end=/$/ contains=LauncherStart,LauncherStop,LauncherScriptName

hi def link LauncherStart MoreMsg
hi def link LauncherStop WarningMsg
hi def link LauncherScriptEntry Normal
hi def link LauncherScriptName Title

hi link NormalFloat Normal

let b:current_syntax = "launcher-control-panel"
