if exists('g:loaded_searchbox_nvim')
  finish
endif
let g:loaded_searchbox_nvim = 1

highlight link SearchBoxMatch Search

command! -range -nargs=* SearchBoxIncSearch lua require('searchbox.command').run('incsearch', <line1>, <line2>, <count>, <q-args>)
command! -range -nargs=* SearchBoxMatchAll lua require('searchbox.command').run('match_all', <line1>, <line2>, <count>, <q-args>)
command! -range -nargs=* SearchBoxSimple lua require('searchbox.command').run('simple', <line1>, <line2>, <count>, <q-args>)
command! -range -nargs=* SearchBoxReplace lua require('searchbox.command').run('replace', <line1>, <line2>, <count>, <q-args>)

command! SearchBoxClear lua require('searchbox').clear_matches()
