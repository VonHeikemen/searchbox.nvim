local M = {}

M.hl_name = 'SearchBoxMatch'
M.hl_namespace = vim.api.nvim_create_namespace(M.hl_name)

M.clear_matches = function(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, M.hl_namespace, 0, -1)
end

M.win_exe = function(winid)
  return function(cmd, args)
    args = args or {}
    return vim.fn.win_execute(winid, cmd:format(unpack(args)))
  end
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

M.build_search = function(value, opts)
  if opts.exact then
    return ('\\<%s\\>'):format(value)
  else
    return value
  end
end

return M

