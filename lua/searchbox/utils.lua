local M = {}
local format = string.format

M.hl_name = 'SearchBoxMatch'
M.hl_namespace = vim.api.nvim_create_namespace(M.hl_name)

M.clear_matches = function(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, M.hl_namespace, 0, -1)
end

M.feedkeys = function(keys)
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes(keys, true, true, true),
    'i',
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
      local keys = rhs
      rhs = function() M.feedkeys(keys) end
    end

    input:map('i', lhs, rhs, {noremap = true}, force)
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

  return query
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

