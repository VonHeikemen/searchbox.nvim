local M = {}

local Input = require('nui.input')
local event = require('nui.utils.autocmd').event

local utils = require('searchbox.utils')

M.search = function(config, search_opts, handlers)
  local cursor = vim.fn.getcurpos()

  local state = {
    match_ns = utils.hl_namespace,
    winid = vim.fn.win_getid(),
    bufnr = vim.fn.bufnr(),
    line = cursor[2],
    line_prev = -1,
  }

  local title = utils.set_title(search_opts, config)
  local popup_opts = config.popup

  if title ~= '' then
    popup_opts = utils.merge(config.popup, {border = {text = {top = title}}})
  end

  local input = Input(popup_opts, {
    prompt = search_opts.prompt,
    default_value = search_opts.default_value or '',
    on_close = function()
      vim.cmd("normal `'")
      handlers.on_close(state)
    end,
    on_submit = function(value)
      local query = utils.build_search(value, search_opts)
      vim.fn.setreg('/', query)
      vim.fn.histadd('search', query)
      handlers.on_submit(value, search_opts, state, popup_opts)
    end,
    on_change = function(value)
      handlers.on_change(value, search_opts, state, utils.win_exe(state.winid))
    end,
  })

  vim.cmd("normal m'")
  config.hooks.before_mount(input)

  input:mount()
  M.default_mappings(input, state.winid)

  config.hooks.after_mount(input)

  input:on(event.BufLeave, function()
    handlers.buf_leave(state)
    input:unmount()
  end)
end

M.default_mappings = function(input, winid)
  local map = utils.create_map(input, false)

  map('<C-c>', input.input_props.on_close)
  map('<Esc>', input.input_props.on_close)

  map('<C-y>', function()
    vim.fn.win_execute(winid, 'exe "normal \\<C-y>"')
  end)
  map('<C-e>', function()
    vim.fn.win_execute(winid, 'exe "normal \\<C-e>"')
  end)
end

return M

