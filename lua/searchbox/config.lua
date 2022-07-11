--
-- config.lua
--

local utils = require('searchbox.utils.pure')
local merge = utils.merge

local M = {}

M.MODE = {
  MIN = 0,
  exact = 1,
  pattern = 2,
  fuzzy = 3,
  MAX = 4,
}

M.search_defaults = {
  reverse = false,
  mode = M.MODE.pattern,
  visual_mode = false,
  title = false,
  case_sensitive = false,
  prompt = ' ',
  range = {-1, -1}
}

M.defaults = {
  icons = {
    search = ' ',
    case_sensitive = ' ',
    pattern = ' ',
    fuzzy = ' ',
  },
  popup = {
    relative = 'win',
    position = {
      row = '5%',
      col = '95%',
    },
    size = 30,
    border = {
      style = 'rounded',
      highlight = 'FloatBorder',
      text = {
        top = ' Search ',
        top_align = 'left',
      },
    },
    win_options = {
      winhighlight = 'Normal:Normal',
    },
  },
  hooks = {
    before_mount = function() end,
    after_mount = function() end,
    on_done = function() end,
  }
}

M.user_opts = nil

M.setup = function(current_config)
  M.user_opts = merge(M.defaults, current_config)
end

M.get = function()
  if not M.user_opts then
    M.setup({})
  end
  return M.user_opts
end

return M
