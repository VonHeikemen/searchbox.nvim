if exists('g:loaded_searchbox_nvim')
  finish
endif
let g:loaded_searchbox_nvim = 1

highlight link SearchBoxMatch Search

command! SearchBoxClear lua require('searchbox').clear_matches()
