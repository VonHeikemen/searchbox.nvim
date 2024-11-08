local M = {}
local s = {}

local Input = require('nui.input')
local event = require('nui.utils.autocmd').event

M.state = {
  last_search = '',
}

local utils = require('searchbox.utils')

M.last_search = function()
  return M.state.last_search
end

M.search = function(config, search_opts, handlers)
  local cursor = vim.fn.getcurpos()

  local state = {
    current_value = '',
    cursor_moved = false,
    match_ns = utils.hl_namespace,
    winid = vim.fn.win_getid(),
    bufnr = vim.fn.bufnr(),
    line = cursor[2],
    line_prev = -1,
    use_range = false,
    start_cursor = {cursor[2], cursor[3]},
    range = {start = {0, 0}, ends = {0, 0}},
    total_matches = '?',
    search_count_index = '?',
  }

  state.current_cursor = state.start_cursor

  if search_opts.visual_mode then
    -- always go nomal mode before getting visual text range
    vim.cmd([[ execute "normal! \<ESC>" ]])
    state.range = {
      start = {vim.fn.line("'<"), vim.fn.col("'<")},
      ends = {vim.fn.line("'>"), vim.fn.col("'>")},
    }
  elseif search_opts.range[1] > 0 and search_opts.range[2] > 0 then
    state.use_range = true
    state.range = {
      start = {
        search_opts.range[1],
        1
      },
      ends = {
        search_opts.range[2],
        vim.fn.col({search_opts.range[2], '$'})
      },
    }
  end

  state.search_modifier = utils.get_modifier(search_opts.modifier)

  if state.search_modifier == nil then
    local msg = "[SearchBox] - Invalid value for 'modifier' argument"
    vim.notify(msg:format(search_opts.modifier), vim.log.levels.WARN)
    return
  end

  if type(config.hooks.before_mount) == 'function' then
    state.before_mount = config.hooks.before_mount
  end

  if type(config.hooks.after_mount) == 'function' then
    state.after_mount = config.hooks.after_mount
  end

  state.show_matches = false
  if search_opts.show_matches == true then
    search_opts.show_matches = '[{match}/{total}]'
  end

  if type(search_opts.show_matches) == 'string' then
    if search_opts.show_matches == '' then
      state.show_matches = false
      search_opts.show_matches = nil
    else
      state.show_matches = true
    end
  end

  local title = utils.set_title(search_opts, config)
  local popup_opts = config.popup

  if title ~= '' then
    popup_opts = utils.merge(config.popup, {border = {text = {top = title}}})
  end

  local input = nil

  if search_opts.visual_mode and state.range.start[1] == 0 then
    local msg = '[searchbox] Could not find any text selected.'
    vim.notify(msg, vim.log.levels.ERROR)
    return
  end

  input = Input(popup_opts, {
    prompt = search_opts.prompt,
    default_value = search_opts.default_value or '',
    on_close = function()
      state.on_done = config.hooks.on_done
      handlers.on_close(state)
    end,
    on_submit = function(value)
      if #value > 0 then
        M.state.last_search = value
      else
        state.cursor_moved = false
      end

      state.on_done = config.hooks.on_done
      handlers.on_submit(value, search_opts, state, popup_opts)
    end,
    on_change = function(value)
      handlers.on_change(value, search_opts, state)

      if state.show_matches then
        s.update_matches(input, search_opts, state)
      end
    end,
  })

  config.hooks.before_mount(input)

  input:mount()

  input._prompt = search_opts.prompt
  M.default_mappings(input, search_opts, state)

  config.hooks.after_mount(input)

  input:on(event.BufLeave, function()
    handlers.buf_leave(state)
    input:unmount()
  end)
end

M.default_mappings = function(input, search_opts, state)
  local bind = function(modes, lhs, rhs, noremap)
    vim.keymap.set(modes, lhs, rhs, {noremap = noremap, buffer = input.bufnr})
  end

  if vim.fn.has('nvim-0.7') == 0 then
    local prompt = input._prompt
    local prompt_length = 0

    if type(prompt.length) == 'function' then
      prompt_length = prompt:length()
    elseif type(prompt.len) == 'function' then
      prompt_length = prompt:len()
    end

    bind = function(modes, lhs, rhs, noremap)
      for _, mode in ipairs(modes) do
        input:map(mode, lhs, rhs, {noremap = noremap}, true)
      end
    end

    bind('i', '<BS>', function() M.prompt_backspace(prompt_length) end, true)
  end

  local win_exe = function(cmd)
    vim.fn.win_execute(state.winid, string.format('exe "normal! %s"', cmd))
  end

  local move = function(flags)
    vim.api.nvim_buf_call(state.bufnr, function()
      local term
      if search_opts._type == 'replace-last' then
        term = M.state.last_search
      else
        term = state.current_value
      end

      if term == '' then
        return
      end

      local query = utils.build_search(term, search_opts, state)
      local match = utils.nearest_match(query, flags)
      if match.ok == false then
        return
      end

      state.cursor_moved = true
      state.current_cursor = {match.line, match.col}

      if state.show_matches then
        local results = vim.fn.searchcount({recompute = 1})
        state.search_count_index = results.current
        s.update_matches(input, search_opts, state)
      end

      local new_position = {state.current_cursor[1], state.current_cursor[2] - 1}
      vim.api.nvim_win_set_cursor(state.winid, new_position)
      vim.fn.setpos('.', {state.bufnr, match.line, match.col})

      local allow_highlights = {'incsearch', 'replace-last', 'simple'}
      if vim.tbl_contains(allow_highlights, search_opts._type) then
        vim.api.nvim_buf_clear_namespace(state.bufnr, utils.hl_namespace, 0, -1)
        utils.highlight_text(state.bufnr, utils.hl_name, match)
      end
    end)
  end

  local replace_step = function()
    if search_opts._type == 'replace-last' then
      return
    end

    input.input_props.on_close()
    M.state.last_search = state.current_value

    local query = utils.build_search(state.current_value, search_opts, state)
    vim.fn.setreg('/', query)
    vim.fn.histadd('search', query)

    vim.schedule(function()
      require('searchbox').replace_last()
    end)
  end

  bind({'', 'i'}, '<Plug>(searchbox-close)', input.input_props.on_close, true)
  bind({'', 'i'}, '<Plug>(searchbox-replace-step)', replace_step, true)

  bind({'', 'i'}, '<Plug>(searchbox-scroll-up)', function() win_exe('\\<C-y>') end, true)
  bind({'', 'i'}, '<Plug>(searchbox-scroll-down)', function() win_exe('\\<C-e>') end, true)

  bind({'', 'i'}, '<Plug>(searchbox-scroll-page-up)', function() win_exe('\\<C-b>') end, true)
  bind({'', 'i'}, '<Plug>(searchbox-scroll-page-down)', function() win_exe('\\<C-f>') end, true)

  bind({'', 'i'}, '<Plug>(searchbox-prev-match)', function() move('bw') end, true)
  bind({'', 'i'}, '<Plug>(searchbox-next-match)', function() move('w') end, true)

  vim.api.nvim_buf_set_keymap(
    input.bufnr,
    'i',
    '<Plug>(searchbox-last-search)',
    "<C-r>=v:lua.require'searchbox.inputs'.last_search()<cr>",
    {noremap = true, silent = true}
  )

  bind({'i'}, '<C-c>', '<Plug>(searchbox-close)', false)
  bind({'i'}, '<Esc>', '<Plug>(searchbox-close)', false)

  bind({'i'}, '<C-y>', '<Plug>(searchbox-scroll-up)', false)
  bind({'i'}, '<C-e>', '<Plug>(searchbox-scroll-down)', false)

  bind({'i'}, '<C-b>', '<Plug>(searchbox-scroll-page-up)', false)
  bind({'i'}, '<C-f>', '<Plug>(searchbox-scroll-page-down)', false)

  bind({'i'}, '<C-g>', '<Plug>(searchbox-prev-match)', false)
  bind({'i'}, '<C-l>', '<Plug>(searchbox-next-match)', false)

  bind({'i'}, '<M-.>', '<Plug>(searchbox-last-search)', false)
end

-- Default backspace has inconsistent behavior, have to make our own (for now)
-- Taken from here:
-- https://github.com/neovim/neovim/issues/14116#issuecomment-976069244
M.prompt_backspace = function(prompt)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]
  local col = cursor[2]

  if col ~= prompt then
    vim.api.nvim_buf_set_text(0, line - 1, col - 1, line - 1, col, {''})
    vim.api.nvim_win_set_cursor(0, {line, col - 1})
  end
end

s.update_matches = vim.schedule_wrap(function(input, search_opts, state)
  if input.bufnr == nil then
    return
  end

  local total = state.total_matches
  local index = state.search_count_index

  local str = search_opts.show_matches
    :gsub('{total}', total)
    :gsub('{match}', index)

  input.border:set_text('bottom', str, 'right')
end)

return M

