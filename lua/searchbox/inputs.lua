local M = {}

local Input = require('nui.input')
local event = require('nui.utils.autocmd').event

local utils = require('searchbox.utils')

M.search = function(config, search_opts, on_change)
  local cursor = vim.fn.getcurpos()

  local state = {
    match_ns = utils.hl_namespace,
    winid = vim.fn.win_getid(),
    bufnr = vim.fn.bufnr(),
    line = cursor[2],
    line_prev = -1,
  }

  local input = Input(config.popup, {
    prompt = ' ',
    default_value = '',
    on_close = function()
      utils.clear_matches(state.bufnr)
      vim.cmd("normal `'")
    end,
    on_submit = function(value)
      utils.clear_matches(state.bufnr)
      local query = utils.build_search(value, search_opts)
      vim.fn.setreg('/', query)
      vim.fn.histadd('search', query)
      vim.cmd('normal n')
    end,
    on_change = function(value)
      utils.clear_matches(state.bufnr)
      on_change(value, search_opts, state, utils.win_exe(state.winid))
    end,
  })

  vim.cmd("normal m'")
  config.hooks.before_mount(input)

  input:mount()

  local map = utils.create_map(input, false)

  map('<C-c>', input.input_props.on_close)
  map('<Esc>', input.input_props.on_close)

  config.hooks.after_mount(input)

  input:on(event.BufLeave, function()
    input:unmount()
  end)
end

return M

