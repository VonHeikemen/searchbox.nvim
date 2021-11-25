local M = {}
local utils = require('searchbox.utils')
local Input = require('nui.input')

local clear_highlight_namespace = function(state)
  utils.clear_matches(state.bufnr)
end

M.incsearch = {
  buf_leave = clear_highlight_namespace,
  on_close = clear_highlight_namespace,
  on_submit = function(value, opts, state)
    clear_highlight_namespace(state)
    vim.cmd('normal n')
  end,
  on_change = function(value, opts, state, win_exe)
    utils.clear_matches(state.bufnr)

    opts = opts or {}
    local search_flags = 'cn'
    local query = utils.build_search(value, opts)

    if opts.reverse then
      search_flags = 'bcn'
    end

    if value == '' then
      return
    end

    local no_match = '\n[0, 0]'
    local wincmd = [[ echo searchpos("%s", '%s') ]]
    local escaped_query = vim.fn.escape(query, '"')
    local ok, pos = pcall(win_exe, wincmd, {escaped_query, search_flags})

    if not ok or pos == no_match then
      return
    end

    pos = vim.split(pos, ',')
    state.line = tonumber(pos[1]:sub(3))
    local col = tonumber(pos[2]:sub(1, pos[2]:len() - 1))
    local off = col + value:len()

    vim.api.nvim_buf_add_highlight(
      state.bufnr,
      utils.hl_namespace,
      utils.hl_name,
      state.line - 1,
      col - 1,
      off - 1
    )

    if state.line ~= state.line_prev then
      vim.fn.setreg('/', query)
      if opts.reverse then
        win_exe('normal N')
      else
        win_exe('normal n')
      end
      state.line_prev = state.line
    end
end

}

local clear_match_id = function(state)
  pcall(vim.fn.matchdelete, state.highlight_id, state.winid)
end

M.match_all = {
  buf_leave = clear_match_id,
  on_close = clear_match_id,
  on_submit = function(value, opts, state)
    if opts.clear_matches then
      clear_match_id(state)
    end

    if opts.reverse then
      vim.cmd('normal N')
    else
      vim.cmd('normal n')
    end
  end,
  on_change = function(value, opts, state, win_exe)
    clear_match_id(state)
    if value == '' then return end

    opts = opts or {}
    local query = utils.build_search(value, opts)
    state.highlight_id = vim.fn.matchadd(utils.hl_name, query, 10, -1, {window = state.winid})

    M.match_all.highlight_id = state.highlight_id
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
  buf_leave = clear_match_id,
  on_close = clear_match_id,
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
        clear_match_id(state)
        vim.defer_fn(function()
          search_opts.default_value = value
          require('searchbox').replace(search_opts)
        end, 3)
      end,
      on_submit = function(value)
        clear_match_id(state)
        local cmd = [[ %%s//%s/g ]]
        vim.cmd(cmd:format(value))
      end
    })

    input:mount()
    require('searchbox.inputs').default_mappings(input, state.winid)
  end,
}

return M

