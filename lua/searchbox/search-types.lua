local M = {}
local utils = require('searchbox.utils')
local Input = require('nui.input')
local noop = function() end

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

local default_highlight = function(bufnr, pos)
  utils.highlight_text(utils.hl_default, utils.ns_default, bufnr, pos)
end

local current_match_highlight = function(bufnr, pos)
  utils.highlight_text(utils.hl_current, utils.ns_current, bufnr, pos)
end

local set_cursor = function(winid, position)
  vim.api.nvim_win_set_cursor(winid, {position[1], position[2] - 1})
end

local save_query = function(value, search_opts, state)
  local query = utils.build_search(value, search_opts, state)
  vim.fn.setreg('/', query)
  vim.fn.histadd('search', query)
end

M.incsearch = {
  buf_leave = clear_matches,
  on_close = function(state)
    set_cursor(state.winid, state.start_cursor)
    clear_matches(state)
    state.on_done(nil, 'incsearch')
  end,
  on_submit = function(value, opts, state)
    if #value > 0 then
      save_query(value, opts, state)
      if state.cursor_moved then
        set_cursor(state.winid, state.current_cursor)
      end

      local res = vim.fn.search(vim.fn.getreg('/'), 'c')

      if res == 0 then
        set_cursor(state.winid, state.start_cursor)
        local _, err = pcall(vim.cmd, '//')
        print_err(err)
        value = nil
      end
    else
      set_cursor(state.winid, state.start_cursor)
    end

    clear_matches(state)
    state.on_done(value, 'incsearch')
  end,
  on_change = function(value, opts, state)
    utils.clear_matches(state.bufnr)

    if value == '' then
      state.total_matches = '?'
      state.search_count_index = '?'
      return
    end

    state.current_value = value

    opts = opts or {}
    local search_flags = 'c'
    local query = utils.build_search(value, opts, state)
    vim.fn.setreg('/', query)

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

      local results = vim.fn.searchcount({maxcount = -1})
      state.total_matches = results.total
      state.search_count_index = results.current

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
      state.total_matches = 0
      state.search_count_index = 0
      return
    end

    state.line = pos.line
    default_highlight(state.bufnr, pos)

    if state.line ~= state.line_prev then
      vim.api.nvim_win_set_cursor(state.winid, {state.line, pos.col - 1})
      state.line_prev = state.line
    end
  end
}

M.match_all = {
  buf_leave = noop,
  on_close = function(state)
    set_cursor(state.winid, state.start_cursor)
    utils.clear_highlights(state.bufnr)
    state.on_done(nil, 'match_all')
  end,
  on_submit = function(value, opts, state)
    local total = state.total_matches
    local has_match = type(total) == 'number' and total > 0

    if #value > 0 then
      save_query(value, opts, state)
    end

    if has_match then
      if state.cursor_moved then
        set_cursor(state.winid, state.current_cursor)
      else
        set_cursor(state.winid, {state.first_match.line, state.first_match.col})
      end
    else
      set_cursor(state.winid, state.start_cursor)

      if total == 0 then
        local _, err = pcall(vim.cmd, '//')
        print_err(err)
      end

      if total == '?' then
        value = nil
      end
    end

    if opts.clear_matches then
      utils.clear_highlights(state.bufnr)
    end

    state.on_done(value, 'match_all')
  end,
  on_change = function(value, opts, state)
    utils.clear_highlights(state.bufnr)

    if value == '' then
      state.total_matches = '?'
      state.search_count_index = '?'
      return
    end

    state.current_value = value

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
        return {total = 0, current = 0}
      end

      return res
    end)

    state.total_matches = results.total
    state.search_count_index = results.current

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

      default_highlight(state.bufnr, pos)
    end

    -- move to nearest match
    buf_call(state, function()
      vim.fn.setpos('.', {0, cursor_pos[1], cursor_pos[2]})
      local flags = opts.reverse and 'cb' or 'c'
      local nearest = searchpos(flags)
      state.first_match = nearest
      current_match_highlight(state.bufnr, nearest)
      vim.api.nvim_win_set_cursor(state.winid, {nearest.line, nearest.col - 1})
    end)
  end
}

M.simple = {
  buf_leave = noop,
  on_close = function(state)
    set_cursor(state.winid, state.start_cursor)

    if state.cursor_moved then
      clear_matches(state)
    end

    state.on_done(nil, 'simple')
  end,
  on_submit = function(value, opts, state)
    local results = vim.fn.searchcount({recompute = 1})
    local total = results.total

    if value == '' then
      set_cursor(state.winid, state.start_cursor)
      state.on_done(nil, 'simple')
      return
    end

    save_query(value, opts, state)

    if state.cursor_moved then
      clear_matches(state)
    end

    if state.cursor_moved and total > 0 then
      set_cursor(state.winid, state.current_cursor)
      state.on_done(value, 'simple')
      return
    end

    if total == 0 then
      set_cursor(state.winid, state.start_cursor)
    end

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
  on_change = function(value, opts, state)
    if state.cursor_moved then
      clear_matches(state)
    end

    if not opts.show_matches then
      return
    end

    if value == '' then
      state.total_matches = '?'
      state.search_count_index = '?'
      return
    end

    state.current_value = value

    buf_call(state, function()
      local query = utils.build_search(value, opts, state)
      vim.fn.setreg('/', query)

      local ok, results = pcall(vim.fn.searchcount, {maxcount = -1})
      if not ok then
        state.total_matches = 0
        state.search_count_index = 0
        return
      end

      state.total_matches = results.total
      state.search_count_index = results.current
    end)
  end
}

M.replace = {
  buf_leave = function(state)
    utils.clear_highlights(state.bufnr)
  end,
  on_close = function(state)
    set_cursor(state.winid, state.start_cursor)
    utils.clear_highlights(state.bufnr)
    state.on_done(nil, 'replace')
  end,
  on_change = M.match_all.on_change,
  on_submit = function(value, search_opts, state, popup_opts)
    if value == '' then
      state.on_done(nil, 'replace')
      return
    end

    save_query(value, search_opts, state)

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

    if state.show_matches then
      border.border.text.bottom = ''
    end

    local replace_popup = utils.merge(popup_opts, border)

    local input = Input(replace_popup, {
      prompt = ' ',
      default_value = '',
      on_close = function()
        utils.clear_highlights(state.bufnr)
        vim.defer_fn(function()
          search_opts.default_value = value
          require('searchbox').replace(search_opts)
        end, 3)
      end,
      on_submit = function(value)
        utils.clear_highlights(state.bufnr)
        M.replace_exec('replace', value, search_opts, state)
      end
    })

    if state.before_mount then
      state.before_mount(input)
    end

    input:mount()
    input._prompt = ' '
    require('searchbox.inputs').default_mappings(input, search_opts, state)

    if state.after_mount then
      state.after_mount(input)
    end
  end,
}

M.replace_last = {
  buf_leave = noop,
  on_change = noop,
  on_close = function(state)
    set_cursor(state.winid, state.start_cursor)

    if state.cursor_moved then
      clear_matches(state)
    end

    state.on_done(nil, 'replace-last')
  end,
  on_submit = function(value, search_opts, state, popup_opts)
    if state.cursor_moved then
      clear_matches(state)
    end

    if value == '' then
      state.on_done(nil, 'replace-last')
      return
    end

    local ok, results = pcall(vim.fn.searchcount, {maxcount = -1})
    if not ok then
      state.on_done(nil, 'replace-last')
      return
    end

    state.total_matches = results.total
    M.replace_exec('replace-last', value, search_opts, state)
  end
}

M.replace_exec = function(search_type, value, search_opts, state)
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
    return M.confirm(search_type, value, state)
  end

  -- change to native confirm if there isn't enough space
  if search_opts.confirm == 'menu' then
    replace_cmd = cmd:format(range, replacement, 'gc')
  end

  local ok, err = pcall(vim.cmd, replace_cmd)

  if ok then
    state.on_done(value, search_type)
  else
    print_err(err)
    state.on_done(nil, search_type)
  end
end

M.confirm = function(search_type, value, state)
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
      state.on_done(value, search_type)
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
    default_highlight(state.bufnr, pos)

    -- Make the confirm menu appear below the match
    if pos.one_line then
      cursor_pos({pos.line, pos.col - 1})
    else
      cursor_pos({pos.end_line, pos.end_col - 15})
    end

    menu.confirm_action({
      on_close = function()
        clear_matches(state)
        state.on_done(value, search_type)
      end,
      on_submit = function(item)
        fn.execute(item, pos)
      end
    })
  end

  if state.first_match then
    fn.confirm(state.first_match)
    return
  end

  local match = next_match()
  if match.ok then
    fn.confirm(match)
    return
  end

  local _, err = pcall(vim.cmd, '//')
  print_err(err)
  state.on_done(nil, search_type)
end

M.grep = {
  buf_leave = noop,
  on_change = noop,
  on_close = function(state)
    state.on_done(nil, 'grep')
  end,
  on_submit = function(value, opts, state, popup_opts)
    local query
    local popup
    local args = {}
    local grep = opts.grep
    local query_flags = value:sub(1, 1) == '-'

    local input_state = require('searchbox.inputs').state

    if type(grep.flags) == 'table' then
      vim.list_extend(args, grep.flags)
    end

    if type(opts.grep_modifier) == 'table' then
      vim.list_extend(args, opts.grep_modifier)
    end

    if query_flags then
      local parts = vim.split(value, ' -- ')
      local flags = vim.split(parts[1], ' ')
      if parts[2] and flags[#flags] == '-' then
        flags[#flags] = nil
      end

      vim.list_extend(args, flags)
      if parts[2] then
        query = parts[2]
        vim.list_extend(args, {query})
      else
        query = args[#args]
      end
    else
      query = value
      vim.list_extend(args, {value})
    end

    input_state.last_search = query

    local matches = 0
    local output = {}
    local on_done = function(result)
      pcall(function()
        if popup == nil then
          return
        end

        popup:unmount()
        input_state.grep_popup = nil
      end)

      input_state.grep_pid = 0
      local ok = result.code == 0
      if not ok then
        if #result.stderr > 0 then
          vim.notify(table.concat(result.stderr), vim.log.levels.ERROR)
        end

        state.on_done(nil, 'grep')
        return
      end

      if #output == 0 then
        state.on_done(nil, 'grep')
        return
      end

      output = table.concat(output)
      local lines = {}
      for l in vim.gsplit(output, '\n') do
        lines[#lines + 1] = l
      end

      if lines[#lines] == '' then
        lines[#lines] = nil
      end

      vim.fn.setqflist({}, ' ', {
        title = 'Grep: ' .. query,
        lines = lines,
        efm = grep.quickfix_format
      })

      if grep.quickfix_window then
        vim.cmd('copen')
      end

      state.on_done(query, 'grep')
    end

    local progress_popup = {
      relative = popup_opts.relative,
      position = popup_opts.position,
      border = popup_opts.border,
      win_options = popup_opts.win_options,
      size = {
        width = 30,
        height = 1
      },
      buf_options = {
        modifiable = true,
        readonly = false,
      },
    }

    local progress_update = function() end
    if grep.show_progress == 'popup' then
      local border_style = vim.tbl_get(popup_opts, 'border', 'style')
      if progress_popup.border and border_style then
        progress_popup.border.text = {
          top = ' Grep progress ',
          top_align = 'left',
        }
      end

      popup = require('nui.popup')(progress_popup)
      progress_update = function()
        if popup == nil then
          return
        end

        pcall(function()
          local msg = ' %s results found'
          vim.api.nvim_buf_set_lines(popup.bufnr, 0, 1, false, {msg:format(matches)})
        end)
      end
    elseif grep.show_progress == 'echo' then
      progress_update = function()
        local msg = '[SearchBox grep] %s results found'
        vim.api.nvim_echo({{msg:format(matches), 'MoreMsg'}}, false, {})
      end
    end

    local spawn_handlers = {
      on_data = function(chunk)
        local substr

        chunk = chunk:gsub('\r\n', '\n')
        output[#output + 1] = chunk

        local nl = chunk:find('\n')
        if nl then
          substr = chunk:sub(nl + 1)
        else
          matches = matches + 1
          vim.schedule(progress_update)
          return
        end

        while nl do
          local i = substr:find('\n')
          if i == nil then
            matches = matches + 1
            break
          end

          nl = i
          matches = matches + 1
          substr = substr:sub(nl + 1)
        end
        vim.schedule(progress_update)
      end,
      on_exit = function(result)
        vim.defer_fn(function() on_done(result) end, 1)
      end,
    }

    local pid = utils.uv_spawn(grep.executable, args, spawn_handlers)
    if pid == nil then
      local msg = "[SearchBox grep] Failed to execute '%s'"
      vim.notify(msg:format(grep.executable), vim.log.levels.ERROR)
      return
    end

    input_state.grep_pid = pid

    if popup then
      popup:mount()
      input_state.grep_popup = popup
      vim.api.nvim_buf_set_lines(popup.bufnr, 0, 1, false, {' Searching...'})
    elseif grep.show_progress == 'echo' then
      local msg = '[SearchBox grep] Searching %s'
      vim.api.nvim_echo({{msg:format(query), 'MoreMsg'}}, true, {})
    end
  end,
}

return M

