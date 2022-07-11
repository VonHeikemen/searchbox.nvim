local config = require('searchbox.config')

local M = {}
local format = string.format
local map = vim.tbl_map
local filter = vim.tbl_filter

M.hl_name         = 'SearchBoxMatch'
M.hl_name_current = 'SearchBoxMatchCurrent'
M.hl_namespace = vim.api.nvim_create_namespace(M.hl_name)

M.clear_matches = function(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, M.hl_namespace, 0, -1)
  vim.cmd('nohlsearch')
end

M.feedkeys = function(keys)
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes(keys, true, true, true),
    'i',
    true
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

M.build_search = function(value, state)
  local opts = state.search_opts
  local query = value

  if opts.mode == config.MODE.exact then
    query = '\\V' .. vim.fn.escape(query, '\\')
  elseif opts.mode == config.MODE.fuzzy then
    -- Don't start matching before 2 charts
    if #value < 2 then
      return nil
    end
    local parts = filter(function(part) return part ~= '' end, vim.split(query, '%s+'))
    local word_matchers = map(function(part)
      local chars = vim.split(part, '')
      local escaped_chars = map(function(c) return vim.fn.escape(c, '\\') end, chars)
      return table.concat(escaped_chars, '[^ ]{-}')
    end, parts)
    local matcher = table.concat(word_matchers, '.{-}')

    query = '\\v' .. matcher
  else
    query = '\\v' .. query
  end
  if opts.case_sensitive then
    query = '\\C' .. query
  else
    -- Don't add '\c': the user might have smartcase on
    -- query = '\\c' .. query
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

M.print_err = function(err)
  local idx = err:find(':E')
  local msg = err:sub(idx + 1)
  vim.notify(msg, vim.log.levels.ERROR)
end

M.print_warn = function(msg)
  vim.notify(msg, vim.log.levels.WARN)
end

M.highlight_text = function(bufnr, pos, hl_name)
  local h = function(line, col, offset)
    vim.api.nvim_buf_add_highlight(
      bufnr,
      M.hl_namespace,
      hl_name or M.hl_name,
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

M.is_position_equal = function(a, b)
  if a == b then return true end
  if a == nil then return false end
  if b == nil then return false end
  return a[1] == b[1] and a[2] == b[2]
end

M.to_position = function(result)
  return {result.line, result.col}
end


return M

