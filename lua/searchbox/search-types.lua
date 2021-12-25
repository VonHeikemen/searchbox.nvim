local M = {}
local utils = require('searchbox.utils')
local Input = require('nui.input')
local fmt = string.format

local buf_call = function(state, fn)
  return vim.api.nvim_buf_call(state.bufnr, fn)
end

local clear_matches = function(state)
  utils.clear_matches(state.bufnr)
end

local print_err = function(err)
  local idx = err:find(':E')
  local msg = err:sub(idx + 1)
  vim.notify(msg, vim.log.levels.ERROR)
end

local highlight_text = function(bufnr, pos)
  local h = function(line, col, offset)
    vim.api.nvim_buf_add_highlight(
      bufnr,
      utils.hl_namespace,
      utils.hl_name,
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

M.incsearch = {
  buf_leave = clear_matches,
  on_close = function(state)
    clear_matches(state)
    state.on_done(nil, 'incsearch')
  end,
  on_submit = function(value, opts, state)
    local res = vim.fn.search(vim.fn.getreg('/'), 'c')

    if res == 0 then
      local _, err = pcall(vim.cmd, '//')
      print_err(err)
    end

    clear_matches(state)
    state.on_done(value, 'incsearch')
  end,
  on_change = function(value, opts, state)
    utils.clear_matches(state.bufnr)

    if value == '' then
      return
    end

    opts = opts or {}
    local search_flags = 'c'
    local query = utils.build_search(value, opts, state)

    if opts.reverse then
      search_flags = 'bc'
    end

    local start_pos = opts.visual_mode
      and state.range.start
      or state.start_cursor

    local searchpos = function()
      vim.fn.setpos('.', {state.bufnr, start_pos[1], start_pos[2]})

      local ok, pos = pcall(vim.fn.searchpos, query, search_flags, state.range.ends[1])
      if not ok then
        return {line = 0, col = 0}
      end

      local offset = vim.fn.searchpos(query, 'cne')

      return {
        line = pos[1],
        col = pos[2],
        end_line = offset[1],
        end_col = offset[2],
        one_line = offset[1] == pos[1],
      }
    end

    local pos = vim.api.nvim_buf_call(state.bufnr, searchpos)
    local no_match = pos.line == 0 and pos.col == 0

    if no_match then
      return
    end

    state.line = pos.line
    highlight_text(state.bufnr, pos)

    if state.line ~= state.line_prev then
      vim.api.nvim_win_set_cursor(state.winid, {state.line, pos.col - 1})
      state.line_prev = state.line
    end
  end
}

M.match_all = {
  buf_leave = clear_matches,
  on_close = function(state)
    clear_matches(state)
    state.on_done(nil, 'match_all')
  end,
  on_submit = function(value, opts, state)
    local cmd = 'normal n'
    if opts.reverse then
      cmd = 'normal N'
    end

    local ok, err = pcall(vim.cmd, cmd)
    if not ok then
      print_err(err)
    end

    if opts.clear_matches then
      clear_matches(state)
    end

    state.on_done(value, 'match_all')
  end,
  on_change = function(value, opts, state)
    utils.clear_matches(state.bufnr)
    if value == '' then return end

    -- figure out 'maxcount' for searchcount
    state.max_match = state.max_match or buf_call(state, function()
      local size = vim.fn.getfsize(vim.fn.expand('%'))

      if size < 0 then
        size = vim.o.lines * 10000
      end

      return size
    end)

    opts = opts or {}
    local query = utils.build_search(value, opts, state)

    local searchpos = function()
      local stopline = state.range.ends[1]
      local ok, pos = pcall(vim.fn.searchpos, query, '', stopline)
      if not ok then
        return {line = 0, col = 0}
      end

      local offset = vim.fn.searchpos(query, 'cne', stopline)

      return {
        line = pos[1],
        col = pos[2],
        end_line = offset[1],
        end_col = offset[2],
        one_line = offset[1] == pos[1],
      }
    end

    vim.fn.setreg('/', query)
    local results = buf_call(state, function()
      return vim.fn.searchcount({maxcount = state.max_match})
    end)

    state.total_matches = results.total

    if results.total == 0 then
      return
    end

    buf_call(state, function()
      local start = state.range.start
      vim.fn.setpos('.', {0, start[1], start[2]})
    end)

    for i = 1, results.total, 1 do
      local pos = buf_call(state, searchpos)

      -- check if there is a match
      if pos.line == 0 and pos.col == 0 then
        break
      end

      if i == 1 then
        state.first_match = pos
      end

      highlight_text(state.bufnr, pos)
    end

    local pos = opts.visual_mode
      and state.range.start
      or state.start_cursor

    buf_call(state, function()
      vim.fn.setpos('.', {0, pos[1], pos[2]})
    end)
  end
}

local noop = function() end
M.simple = {
  buf_leave = noop,
  on_close = function(state)
    state.on_done(nil, 'simple')
  end,
  on_submit = function(value, opts, state)
    local cmd = 'normal! n'
    if opts.reverse then
      cmd = 'normal! N'
    end

    local ok, err = pcall(vim.cmd, cmd)
    if not ok then
      print_err(err)
    end

    state.on_done(value, 'simple')
  end,
  on_change = noop
}

M.replace = {
  buf_leave = clear_matches,
  on_close = function(state)
    clear_matches(state)
    state.on_done(nil, 'replace')
  end,
  on_change = M.match_all.on_change,
  on_submit = function(value, search_opts, state, popup_opts)
    if state.total_matches == 0 then
      local _, err = pcall(vim.cmd, '//')
      print_err(err)
      state.on_done(nil, 'replace')
      return
    end

    local border = {
      border = {
        text = {
          top = ' With ',
          bottom = ' 2/2 ',
          bottom_align = 'right'
        }
      }
    }

    local replace_popup = utils.merge(popup_opts, border)

    local input = Input(replace_popup, {
      prompt = ' ',
      default_value = '',
      on_close = function()
        clear_matches(state)
        vim.defer_fn(function()
          search_opts.default_value = value
          require('searchbox').replace(search_opts)
        end, 3)
      end,
      on_submit = function(value)
        clear_matches(state)
        local flags = 'g'

        if search_opts.confirm == 'native' then
          flags = 'gc'
        end

        local screen = vim.opt.lines:get()
        local enough_space = screen >= 14
        local range = search_opts.visual_mode and "'<,'>s" or '%s'
        local cmd = [[ %s//%s/%s ]]
        local replacement = vim.fn.escape(value, '/')

        local replace_cmd = cmd:format(range, replacement, flags)

        if search_opts.confirm == 'menu' and enough_space then
          return M.confirm(value, state)
        end

        -- change to native confirm if there isn't enough space
        if search_opts.confirm == 'menu' then
          replace_cmd = cmd:format(range, replacement, 'gc')
        end

        vim.cmd(replace_cmd)
        state.on_done(value, 'replace')
      end
    })

    input:mount()
    require('searchbox.inputs').default_mappings(input, state.winid)
  end,
}

M.confirm = function(value, state)
  local fn = {}
  local match_index = 0
  local menu = require('searchbox.replace-menu')
  local next_match = function()
    local pos = vim.fn.searchpos(vim.fn.getreg('/'), 'cw')
    local off = vim.fn.searchpos(vim.fn.getreg('/'), 'cwe')

    return {
      line = pos[1],
      col = pos[2],
      end_line = off[1],
      end_col = off[2],
      one_line = pos[1] == off[1]
    }
  end

  local replace = function(pos)
    vim.api.nvim_buf_set_text(
      0,
      pos.line - 1,
      pos.col - 1,
      pos.end_line - 1,
      pos.end_col,
      {value}
    )

    -- move cursor to the new offset column
    -- so next_match doesn't get stuck
    vim.api.nvim_win_set_cursor(state.winid, {pos.line, (pos.col + value:len()) - 1})
  end

  local cursor_pos = function(pos)
    local line = pos[1]
    local col = pos[2] <= 0 and 0 or pos[2] - 1
    vim.api.nvim_win_set_cursor(state.winid, {line, col})
  end

  fn.execute = function(item, pos)
    match_index = match_index + 1
    clear_matches(state)

    local is_last = match_index == state.total_matches

    local stop = true
    local replace_next = false

    if item.action == 'replace' then
      replace(pos)
      stop = false
    end

    if item.action == 'replace_all' then
      replace(pos)
      replace_next = true
      stop = false
    end

    if item.action == 'next' then
      -- move so next_match can do the right thing.
      cursor_pos({pos.end_line, pos.end_col})
      stop = false
    end

    if item.action == 'quit' then
      stop = true
    end

    if item.action == 'last' then
      replace(pos)
      stop = true
    end

    if stop or is_last then
      state.on_done(value, 'replace')
      return
    end

    local match = next_match()
    if match.line == 0 and match.col == 0 then
      return
    end

    if replace_next then
      fn.execute({action = 'replace_all'}, match)
    else
      fn.confirm(match)
    end
  end

  fn.confirm = function(pos)
    clear_matches(state)
    highlight_text(state.bufnr, pos)

    -- Make the confirm menu appear below the match
    if pos.one_line then
      cursor_pos({pos.line, pos.col - 1})
    else
      cursor_pos({pos.end_line, pos.end_col - 15})
    end

    menu.confirm_action({
      on_close = function()
        clear_matches(state)
      end,
      on_submit = function(item)
        fn.execute(item, pos)
      end
    })
  end

  fn.confirm(next_match())
end

return M

