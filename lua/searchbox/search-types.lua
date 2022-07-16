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
  utils.highlight_text(bufnr, utils.hl_name, pos)
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
    if state.total_matches == 0 then
      local _, err = pcall(vim.cmd, '//')
      print_err(err)
    end

    if opts.clear_matches then
      clear_matches(state)
    end

    -- Make sure you land on the first match.
    -- Y'all can blame netrw for this one.
    vim.api.nvim_win_set_cursor(
      state.winid,
      {state.first_match.line, state.first_match.col - 1}
    )

    state.on_done(value, 'match_all')
  end,
  on_change = function(value, opts, state)
    utils.clear_matches(state.bufnr)
    if value == '' then return end

    opts = opts or {}
    local query = utils.build_search(value, opts, state)

    local searchpos = function(flags)
      local stopline = state.range.ends[1]
      local ok, pos = pcall(vim.fn.searchpos, query, flags, stopline)
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
      local ok, res = pcall(vim.fn.searchcount, {maxcount = -1})
      if not ok then
        return {total = 0}
      end

      return res
    end)

    state.total_matches = results.total
    local cursor_pos = opts.visual_mode
      and state.range.start
      or state.start_cursor

    if results.total == 0 then
      -- restore cursor position
      buf_call(state, function()
        vim.fn.setpos('.', {0, cursor_pos[1], cursor_pos[2]})
        vim.api.nvim_win_set_cursor(state.winid, cursor_pos)
      end)
      return
    end

    buf_call(state, function()
      local start = state.range.start
      vim.fn.setpos('.', {0, start[1], start[2]})
    end)

    -- highlight all the things
    for i = 1, results.total, 1 do
      local flags = i == 1 and 'c' or ''
      local pos = buf_call(state, function() return searchpos(flags) end)

      -- check if there is a match
      if pos.line == 0 and pos.col == 0 then
        break
      end

      highlight_text(state.bufnr, pos)
    end

    -- move to nearest match
    buf_call(state, function()
      vim.fn.setpos('.', {0, cursor_pos[1], cursor_pos[2]})
      local flags = opts.reverse and 'cb' or 'c'
      local nearest = searchpos(flags)
      state.first_match = nearest
      vim.api.nvim_win_set_cursor(state.winid, {nearest.line, nearest.col})
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
    input._prompt = ' '
    require('searchbox.inputs').default_mappings(input, search_opts, state)
  end,
}

M.confirm = function(value, state)
  local fn = {}
  local match_index = 0
  local menu = require('searchbox.replace-menu')
  local search_term = vim.fn.getreg('/')

  local next_match = function()
    return utils.nearest_match(search_term, 'cw')
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
    vim.api.nvim_win_set_cursor(state.winid, {
      pos.line,
      (pos.col + value:len()) - 1
    })
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
      local offset = search_term:len() > 1 and 0 or 1
      cursor_pos({pos.end_line, pos.end_col + offset})
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
        state.on_done(value, 'replace')
      end,
      on_submit = function(item)
        fn.execute(item, pos)
      end
    })
  end

  fn.confirm(state.first_match)
end

return M

