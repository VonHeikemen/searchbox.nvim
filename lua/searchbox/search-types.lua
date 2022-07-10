local M = {}
local utils = require('searchbox.utils')
local Input = require('nui.input')
local fmt = string.format
local highlight_text = utils.highlight_text
local is_position_equal = utils.is_position_equal

local buf_call = function(state, fn)
  return vim.api.nvim_buf_call(state.bufnr, fn)
end

local move_cursor = function(state, position)
  vim.fn.setpos('.', {0, position[1], position[2]})
  vim.api.nvim_win_set_cursor(state.winid, {position[1], position[2] - 1})
end

local clear_matches = function(state)
  utils.clear_matches(state.bufnr)
end

local searchpos = function(state, flags)
  local stopline = state.range.ends[1]
  local ok, pos = pcall(vim.fn.searchpos, state.query, flags, stopline)
  if not ok then
    return {line = 0, col = 0}
  end

  local offset = vim.fn.searchpos(state.query, 'cne', stopline)

  return {
    line = pos[1],
    col = pos[2],
    end_line = offset[1],
    end_col = offset[2],
    one_line = offset[1] == pos[1],
  }
end

local function update_bottom_border(state, input, content)
  vim.defer_fn(function()
    input.border:set_text('bottom', content, 'right')
  end, 0)
end


M.incsearch = {
  buf_leave = clear_matches,
  on_close = function(state)
    clear_matches(state)
    state.on_done(nil, 'incsearch')
  end,
  on_submit = function(value, state)
    local res = vim.fn.search(vim.fn.getreg('/'), 'c')

    if res == 0 then
      local _, err = pcall(vim.cmd, '//')
      utils.print_err(err)
    end

    clear_matches(state)
    state.on_done(value, 'incsearch')
  end,
  on_change = function(value, state)
    local opts = state.search_opts
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

    local searchpos_incsearch = function()
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

    local pos = vim.api.nvim_buf_call(state.bufnr, searchpos_incsearch)
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

local function match_all_highlight(state, input)
  local opts = state.search_opts

  utils.clear_matches(state.bufnr)
  if state.query == '' or state.query == nil then return end

  vim.fn.setreg('/', state.query)
  local results = buf_call(state, function()
    local ok, res = pcall(vim.fn.searchcount, {maxcount = -1})
    if not ok then
      return {total = 0}
    end
    return res
  end)

  state.total_matches = results.total

  -- If no match, restore cursor position
  if results.total == 0 then
    buf_call(state, function()
      local cursor_pos = opts.visual_mode
        and state.range.start
        or state.current_cursor

      vim.fn.setpos('.', {0, cursor_pos[1], cursor_pos[2]})
      vim.api.nvim_win_set_cursor(state.winid, cursor_pos)
    end)
    update_bottom_border(state, input, 'No matches')
    return
  end

  -- Find nearest match
  if state.first_match == nil then
    buf_call(state, function()
      move_cursor(state, state.current_cursor)
      local flags = opts.reverse and 'cbn' or 'cn'
      local nearest = searchpos(state, flags)
      state.first_match = utils.to_position(nearest)
    end)
  end

  -- Position at start of range
  buf_call(state, function()
    local start = state.range.start
    vim.fn.setpos('.', {0, start[1], start[2]})
  end)

  local current_index = 0

  -- highlight all matches
  for i = 1, results.total, 1 do
    local flags = i == 1 and 'c' or ''
    local pos = buf_call(state, function() return searchpos(state, flags) end)

    -- check if there is a match
    if pos.line == 0 and pos.col == 0 then
      break
    end

    local hl_name = nil
    if is_position_equal({pos.line, pos.col}, state.first_match) then
      hl_name = utils.hl_name_current
      current_index = i
    end

    highlight_text(state.bufnr, pos, hl_name)
  end

  update_bottom_border(state, input, fmt('%i/%i', current_index, results.total))

  -- move to nearest match
  buf_call(state, function()
    move_cursor(state, state.first_match)
  end)

  state.current_cursor = state.first_match
end

local function match_all_move(state, input, forward)
  if state.search_opts.reverse then
    forward = not forward
  end

  local pos = buf_call(state, function()
    move_cursor(state, state.current_cursor)
    local flags = forward and '' or 'b'
    return searchpos(state, flags)
  end)

  -- check if there is a match
  if pos.line == 0 and pos.col == 0 then
    return
  end

  local current_cursor = {pos.line, pos.col}

  buf_call(state, function()
    move_cursor(state, current_cursor)
  end)

  state.current_cursor = current_cursor
  state.first_match = current_cursor

  match_all_highlight(state, input)
end

M.match_all = {
  buf_leave = clear_matches,
  mappings = function(state, input, map, win_exe)
    map('<Tab>',   function() match_all_move(state, input, true) end)
    map('<S-Tab>', function() match_all_move(state, input, false) end)
  end,
  on_change = function(value, state, input)
    state.query = utils.build_search(value, state)
    state.first_match = nil
    match_all_highlight(state, input)
  end,
  on_submit = function(value, state)
    local opts = state.search_opts

    if state.total_matches == 0 then
      local _, err = pcall(vim.cmd, '//')
      utils.print_err(err)
    end

    if opts.clear_matches then
      clear_matches(state)
    end

    -- Make sure you land on the first match.
    -- Y'all can blame netrw for this one.
    vim.api.nvim_win_set_cursor(
      state.winid,
      {state.first_match[1], state.first_match[2] - 1}
    )

    state.on_done(value, 'match_all')
  end,
  on_close = function(state)
    clear_matches(state)
    state.on_done(nil, 'match_all')
  end,
}

local noop = function() end
M.simple = {
  buf_leave = noop,
  on_close = function(state)
    state.on_done(nil, 'simple')
  end,
  on_submit = function(value, state)
    local opts = state.search_opts
    local cmd = 'normal! n'
    if opts.reverse then
      cmd = 'normal! N'
    end

    local ok, err = pcall(vim.cmd, cmd)
    if not ok then
      utils.print_err(err)
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
  on_submit = function(value, state, input, popup_opts)
    local search_opts = state.search_opts
    if state.total_matches == 0 then
      local _, err = pcall(vim.cmd, '//')
      utils.print_err(err)
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
    require('searchbox.inputs').add_mappings(input, state)
  end,
}

M.confirm = function(value, state)
  local fn = {}
  local match_index = 0
  local menu = require('searchbox.replace-menu')
  local search_term = vim.fn.getreg('/')

  local next_match = function()
    local pos = vim.fn.searchpos(search_term, 'cw')
    local off = vim.fn.searchpos(search_term, 'cwe')

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

