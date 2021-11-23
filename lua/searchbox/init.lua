local M = {}

local utils = require('searchbox.utils')
local search_type = require('searchbox.search-types')
local input = require('searchbox.inputs')

local merge = utils.merge

local search_defaults = {
  reverse = false,
  exact = false
}

local defaults = {
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
  }
}

local user_opts = nil

M.setup = function(config)
  user_opts = merge(defaults, config)
end

M.incsearch = function(config)
  local search_opts = merge(search_defaults, config)
  if not user_opts then
    M.setup({})
  end

  input.search(user_opts, search_opts, search_type.incsearch)
end

return M

