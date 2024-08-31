local M = {}
local format = string.format

M.hl_name = 'SearchBoxMatch'
M.hl_namespace = vim.api.nvim_create_namespace(M.hl_name)

M.clear_matches = function(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, M.hl_namespace, 0, -1)
  vim.cmd('nohlsearch')
end

M.feedkeys = function(keys)
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes(keys, true, true, true),
    'n',
    true
  )
end

M.merge = function(defaults, override)
  return vim.tbl_deep_extend(
    'force',
    {},
    defaults,
    override or {}
  )
end

M.create_map = function(input, force)
  return function(lhs, rhs)
    if type(rhs) == 'string' then
      vim.api.nvim_buf_set_keymap(input.bufnr, 'i', lhs, rhs, {noremap = true})
      return
    end

    input:map('i', lhs, rhs, {noremap = true}, force)
  end
end

M.get_modifier = function(name)
  local mods = {
    ['disabled'] = '',
    ['ignore-case'] = '\\c',
    ['case-sensitive'] = '\\C',
    ['no-magic'] = '\\M',
    ['magic'] = '\\m',
    ['very-magic'] = '\\v',
    ['very-no-magic'] = '\\V',
    ['plain'] = '\\V'
  }

  local modifier = mods[name]

  if modifier then
    return modifier
  end

  if type(name) == 'string' and name:sub(1, 1) == ':' then
    return name:sub(2)
  end
end

M.build_search = function(value, opts, state)
  local query = value

  if opts.exact then
    query = format('\\<%s\\>', query)
  end

  if opts.visual_mode then
    query = format('\\%%V%s', query)
  elseif state.use_range then
    query = format(
      '\\%%>%sl\\%%<%sl%s',
      state.range.start[1] - 1,
      state.range.ends[1] + 1,
      value
    )
  end

  query = format('%s%s', state.search_modifier, query)

  return query
end

M.nearest_match = function(search_term, flags)
  local pos = vim.fn.searchpos(search_term, flags)
  local off = vim.fn.searchpos(search_term, 'cne')
  local empty = pos[1] == 0 and pos[2] == 0

  return {
    ok = not empty,
    line = pos[1],
    col = pos[2],
    end_line = off[1],
    end_col = off[2],
    one_line = pos[1] == off[1]
  }
end

M.move_cursor = function(winid, pos)
  vim.fn.setpos('.', {0, pos[1], pos[2]})
  vim.api.nvim_win_set_cursor(winid, pos)
end

M.highlight_text = function(bufnr, hl_name, pos)
  local h = function(line, col, offset)
    vim.api.nvim_buf_add_highlight(
      bufnr,
      M.hl_namespace,
      hl_name,
      line - 1,
      col - 1,
      offset
    )
  end

  if pos.one_line then
    h(pos.line, pos.col, pos.end_col)
  else
    -- highlight first line
    h(pos.line, pos.col, -1)

    -- highlight last line
    h(pos.end_line, 1, pos.end_col)

    -- do the rest
    for curr_line=pos.line + 1, pos.end_line - 1, 1 do
      h(curr_line, 1, -1)
    end
  end
end

M.set_title = function(search_opts, user_opts)
  local ok, title = pcall(function()
    return user_opts.popup.border.text.top
  end)

  if title == nil then
    return ''
  end

  if search_opts.title then
    return search_opts.title
  end

  if title ~= ' Search ' then
    return title
  end

  title = vim.trim(title)
  if search_opts.reverse then
    title = 'Reverse Search'
  end

  if search_opts.exact then
    title = title .. ' (exact)'
  end

  return format(' %s ', title)
end

M.validate_confirm_mode = function(value)
  return value == 'menu' or value == 'native' or value == 'off'
end

return M

