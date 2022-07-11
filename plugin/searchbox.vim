highlight default link SearchBoxMatch Search
highlight default link SearchBoxMatchCurrent Incsearch
highlight default link Incsearch Search

highlight default link SearchBoxWarning WarningMsg
highlight default link SearchBoxSpecial Special

command! -range -nargs=* SearchBoxIncSearch lua require('searchbox.command').run('incsearch', <line1>, <line2>, <count>, <q-args>)
command! -range -nargs=* SearchBoxMatchAll  lua require('searchbox.command').run('match_all', <line1>, <line2>, <count>, <q-args>)
command! -range -nargs=* SearchBoxSimple    lua require('searchbox.command').run('simple',    <line1>, <line2>, <count>, <q-args>)
command! -range -nargs=* SearchBoxReplace   lua require('searchbox.command').run('replace',   <line1>, <line2>, <count>, <q-args>)

command! SearchBoxClear lua require('searchbox').clear_matches()
