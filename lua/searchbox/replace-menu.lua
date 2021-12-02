local M = {}
local Menu = require('nui.menu')
local event = require('nui.utils.autocmd').event

local popup_options = {
  relative = 'cursor',
  position = {
    row = 1,
    col = 0,
  },
  border = {
    style = 'rounded',
    highlight = 'FloatBorder',
    text = {
      top = '[Replace]',
      top_align = 'center',
    },
  },
  highlight = 'Normal:Normal',
}

local move_screen = function()
  local screen = vim.opt.lines:get()

  if screen > 13 and screen < 26 then
    vim.cmd('normal! zt')
  else
    vim.cmd('normal! zz')
  end
end

local get_row = function()
  local cursor_line = vim.fn.line('.')
  local first_line = vim.fn.line('w0')
  local fold = {up = -8, down = 1}

  local height = vim.fn.winheight(0)
  local diff_start = cursor_line - first_line

  local remaining_space = height - (diff_start + 1)

  if remaining_space < 9 then
    return fold.up
  end

  return fold.down
end

M.confirm_action = function(handlers)
  local og_timelen = vim.opt.timeoutlen:get()
  vim.opt.timeoutlen = 3

  move_screen()
  popup_options.position.row = get_row()

  local menu = Menu(popup_options, {
    lines = {
      Menu.item('* Yes', {action = 'replace'}),
      Menu.item('* No', {action = 'next'}),
      Menu.separator(''),
      Menu.item('* All', {action = 'replace_all'}),
      Menu.item('* Quit', {action = 'quit'}),
      Menu.item('* Last replace', {action = 'last'}),
    },
    max_width = 20,
    separator = {
      char = '─',
      text_align = 'center',
    },
    keymap = {
      focus_next = {'j', '<Down>', '<Tab>'},
      focus_prev = {'k', '<Up>', '<S-Tab>'},
      close = {'<Esc>', '<C-c>'},
      submit = {'<CR>'},
    },
    on_close = function()
      vim.opt.timeoutlen = og_timelen
      handlers.on_close()
    end,
    on_submit = function(item)
      vim.opt.timeoutlen = og_timelen
      handlers.on_submit(item)
    end,
  })

  menu:mount()

  menu:on(event.BufLeave, function()
    vim.opt.timeoutlen = og_timelen
  end)

  function map(lhs, rhs)
    vim.api.nvim_buf_set_keymap(menu.bufnr, 'n', lhs, rhs, {noremap = false})
  end

  map('y', 'gg<CR>')
  map('n', '2gg<CR>')
  map('a', '4gg<CR>')
  map('q', '5gg<CR>')
  map('l', '6gg<CR>')
end

return M

