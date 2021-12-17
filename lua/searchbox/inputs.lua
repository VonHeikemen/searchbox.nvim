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
    use_range = false,
    start_cursor = {cursor[2], cursor[3]},
    range = {start = {0, 0}, ends = {0, 0}}
  }

  if search_opts.visual_mode then
    state.range = {
      start = {vim.fn.line("'<"), vim.fn.col("'<")},
      ends = {vim.fn.line("'>"), vim.fn.col("'>")},
    }
  elseif search_opts.range[1] > 0 and search_opts.range[2] > 0 then
    state.use_range = true
    state.range = {
      start = {
        search_opts.range[1],
        1
      },
      ends = {
        search_opts.range[2],
        vim.fn.col({search_opts.range[2], '$'})
      },
    }
  end

  local title = utils.set_title(search_opts, config)
  local popup_opts = config.popup

  if title ~= '' then
    popup_opts = utils.merge(config.popup, {border = {text = {top = title}}})
  end

  local input = Input(popup_opts, {
    prompt = search_opts.prompt,
    default_value = search_opts.default_value or '',
    on_close = function()
      vim.api.nvim_win_set_cursor(state.winid, state.start_cursor)

      state.on_done = config.hooks.on_done
      handlers.on_close(state)
    end,
    on_submit = function(value)
      local query = utils.build_search(value, search_opts, state)
      vim.fn.setreg('/', query)
      vim.fn.histadd('search', query)

      state.on_done = config.hooks.on_done
      handlers.on_submit(value, search_opts, state, popup_opts)
    end,
    on_change = function(value)
      handlers.on_change(value, search_opts, state)
    end,
  })

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
  local prompt = input.input_props.prompt
  local prompt_length = 0

  if type(prompt.length) == 'function' then
    prompt_length = prompt:length()
  elseif type(prompt.len) == 'function' then
    prompt_length = prompt:len()
  end

  local bufmap = function(lhs, rhs)
    vim.api.nvim_buf_set_keymap(input.bufnr, 'i', lhs, rhs, {noremap = true})
  end

  local win_exe = function(cmd)
    vim.fn.win_execute(winid, string.format('exe "normal %s"', cmd))
  end

  map('<C-c>', input.input_props.on_close)
  map('<Esc>', input.input_props.on_close)
  map('<BS>', function() M.prompt_backspace(prompt_length) end)


  map('<C-y>', function() win_exe('\\<C-y>') end)
  map('<C-e>', function() win_exe('\\<C-e>') end)

  map('<C-f>', function() win_exe('\\<C-f>') end)
  map('<C-b>', function() win_exe('\\<C-b>') end)

  bufmap('<M-.>', '<C-r>=getreg("/")<CR>')
end

-- Default backspace has inconsistent behavior, have to make our own (for now)
-- Taken from here:
-- https://github.com/neovim/neovim/issues/14116#issuecomment-976069244
M.prompt_backspace = function(prompt)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]
  local col = cursor[2]

  if col ~= prompt then
    vim.api.nvim_buf_set_text(0, line - 1, col - 1, line - 1, col, {''})
    vim.api.nvim_win_set_cursor(0, {line, col - 1})
  end
end

return M

