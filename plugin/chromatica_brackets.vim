if exists('g:loaded_chromatica_brackets')
  finish
endif
let g:loaded_chromatica_brackets = 1

if has('nvim')
  lua << EOF
  require("chromatica_brackets").setup()
EOF
endif
