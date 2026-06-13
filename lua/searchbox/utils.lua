local M = {}
local format = string.format

M.hl_default = 'SearchBoxMatch'
M.hl_current = 'SearchBoxCurrentMatch'
M.ns_default = vim.api.nvim_create_namespace(M.hl_default)
M.ns_current = vim.api.nvim_create_namespace(M.hl_current)

M.clear_matches = function(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, M.ns_default, 0, -1)
  vim.cmd('nohlsearch')
end

M.clear_highlights = function(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, M.ns_default, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, M.ns_current, 0, -1)
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

M.highlight_text = function(hl_name, hl_namespace, bufnr, pos)
  local h = function(line, col, offset)
    vim.api.nvim_buf_add_highlight(
      bufnr,
      hl_namespace,
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

M.validate_grep = function(opts)
  if type(opts) ~= 'table' then
    return false, 'grep_options is must be a lua table'
  end
  
  if type(opts.executable) ~= 'string' then
    return false, 'Must provide grep executable'
  end

  if type(opts.quickfix_format) ~= 'string' then
    return false, 'Must provide a format string to parse the quickfix list'
  end

  if opts.show_progress == nil then
    opts.show_progress = 'disabled'
  end

  if type(opts.show_progress) ~= 'string' then
    return false, 'The option "show_progress" must be a string'
  end

  local valid_show_progress = {'popup', 'echo', 'disabled'}
  if not vim.tbl_contains(valid_show_progress, opts.show_progress) then
    local msg = string.format(
      '"%s" is not a valid setting for grep show_progress. Possible values include: %s',
      opts.show_progress,
      table.concat(valid_show_progress, ', ')
    )

    return false, msg
  end

  if type(opts.flags) == 'string' then
    opts.flags = vim.split(opts.flags, ' ')
  end

  return true
end

M.uv_spawn = function(cmd, args, handlers)
  local uv = vim.uv or vim.loop
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  local stderr_data = {}
  local proc

  local spawn_opts = {
    args = args,
    hide = true,
    stdio = {nil, stdout, stderr}
  }

  local exit_handler = function(code, signal)
    if proc and not proc:is_closing() then
      proc:close()
    end

    local check = uv.new_check()
    check:start(function()
      for _, h in ipairs({stdout, stderr}) do
        if not h:is_closing() then
          return
        end
      end
      check:stop()
      check:close()
      
      handlers.on_exit({
        code = code,
        signal = signal,
        stderr = stderr_data
      })
    end)
  end

  local error_handler = function()
    local handles = {proc, stdout, stderr}
    for _, h in ipairs(handles) do
      if h and not h:is_closing() then
        h:close()
      end
    end
  end

  proc, pid = uv.spawn(cmd, spawn_opts, exit_handler, error_handler)

  stdout:read_start(function(err, chunk)
    if err then
      error(err)
    end

    if chunk == nil then
      stdout:read_stop()
      stdout:close()
      return
    end

    handlers.on_data(chunk)
  end)

  stderr:read_start(function(err, chunk)
    if err then
      error(err)
    end

    if chunk == nil then
      stderr:read_stop()
      stderr:close()
      return
    end

    stderr_data[#stderr_data + 1] = chunk:gsub('\r\n', '\n')
  end)

  if pid then
    return pid
  end
end

return M

