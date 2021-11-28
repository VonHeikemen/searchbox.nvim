local M = {}
local utils = require('searchbox.utils')
local Input = require('nui.input')

local clear_matches = function(state)
  utils.clear_matches(state.bufnr)
end

M.incsearch = {
  buf_leave = clear_matches,
  on_close = clear_matches,
  on_submit = function(value, opts, state)
    clear_matches(state)
    vim.cmd('normal n')
  end,
  on_change = function(value, opts, state)
    utils.clear_matches(state.bufnr)

    if value == '' then
      return
    end

    opts = opts or {}
    local search_flags = 'c'
    local query = utils.build_search(value, opts)

    if opts.reverse then
      search_flags = 'bc'
    end

    local searchpos = function()
      local pos = state.start_cursor
      vim.fn.setpos('.', {state.bufnr, pos[1], pos[2]})

      local pos = vim.fn.searchpos(query, search_flags)
      local offset = vim.fn.searchpos(query, 'cne')
      pos[3] = offset[2]

      return pos
    end

    local pos = vim.api.nvim_buf_call(state.bufnr, searchpos)
    local no_match = pos[1] == 0 and pos[2] == 0

    if no_match then
      return
    end

    state.line = pos[1]
    local col = pos[2]
    local off = pos[3]

    vim.api.nvim_buf_add_highlight(
      state.bufnr,
      utils.hl_namespace,
      utils.hl_name,
      state.line - 1,
      col - 1,
      off
    )

    if state.line ~= state.line_prev then
      vim.api.nvim_win_set_cursor(state.winid, {state.line, col - 1})
      state.line_prev = state.line
    end
end

}

M.match_all = {
  buf_leave = clear_matches,
  on_close = clear_matches,
  on_submit = function(value, opts, state)
    if opts.clear_matches then
      clear_matches(state)
    end

    if opts.reverse then
      vim.cmd('normal N')
    else
      vim.cmd('normal n')
    end
  end,
  on_change = function(value, opts, state)
    utils.clear_matches(state.bufnr)

    if value == '' then return end

    opts = opts or {}
    local query = utils.build_search(value, opts)

    local searchpos = function()
      local pos = vim.fn.searchpos(query)
      local offset = vim.fn.searchpos(query, 'cne')
      pos[3] = offset[2]
      return pos
    end

    vim.fn.setreg('/', query)
    local results = vim.api.nvim_buf_call(state.bufnr, function()
      return vim.fn.searchcount()
    end)

    if results.total == 0 then
      return
    end

    vim.api.nvim_buf_call(state.bufnr, function()
      vim.fn.setpos('.', {0, 0, 0})
    end)

    for i = 1, results.total, 1 do
      local pos = vim.api.nvim_buf_call(state.bufnr, searchpos)

      local line = pos[1]
      local col = pos[2]
      local off = pos[3]

      vim.api.nvim_buf_add_highlight(
        state.bufnr,
        utils.hl_namespace,
        utils.hl_name,
        line - 1,
        col - 1,
        off
      )
    end

    local pos = state.start_cursor
    vim.api.nvim_buf_call(state.bufnr, function()
      vim.fn.setpos('.', {0, pos[1], pos[2]})
    end)
  end
}

local noop = function() end
M.simple = {
  buf_leave = noop,
  on_close = noop,
  on_submit = function(value, opts, state)
    if opts.reverse then
      vim.cmd('normal N')
    else
      vim.cmd('normal n')
    end
  end,
  on_change = noop
}

M.replace = {
  buf_leave = clear_matches,
  on_close = clear_matches,
  on_change = M.match_all.on_change,
  on_submit = function(value, search_opts, state, popup_opts)
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
        local cmd = [[ %%s//%s/g ]]
        vim.cmd(cmd:format(value))
      end
    })

    input:mount()
    require('searchbox.inputs').default_mappings(input, state.winid)
  end,
}

return M

