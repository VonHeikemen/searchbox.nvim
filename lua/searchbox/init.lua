local M = {}

local utils = require('searchbox.utils')
local search_type = require('searchbox.search-types')
local input = require('searchbox.inputs')

local merge = utils.merge

local search_defaults = {
  reverse = false,
  exact = false,
  prompt = ' ',
  modifier = 'disabled',
  title = false,
  visual_mode = false,
  range = {-1, -1},
}

local defaults = {
  defaults = {}, -- search config defaults
  popup = {
    relative = 'win',
    position = {
      row = '5%',
      col = '95%',
    },
    size = 30,
    border = {
      style = 'rounded',
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

local user_opts = nil

local merge_config = function(opts)
  return vim.tbl_deep_extend(
    'force',
    {},
    search_defaults,
    {
      reverse = user_opts.defaults.reverse,
      exact = user_opts.defaults.exact,
      prompt = user_opts.defaults.prompt,
      modifier = user_opts.defaults.modifier,
      clear_matches = user_opts.defaults.clear_matches,
      confirm = user_opts.defaults.confirm
    },
    opts
  )
end

M.setup = function(config)
  user_opts = merge(defaults, config)
end

M.clear_matches = function()
  utils.clear_matches(vim.fn.bufnr('%'))
end

M.incsearch = function(config)
  if not user_opts then
    M.setup({})
  end

  local search_opts = merge_config(config)
  search_opts._type = 'incsearch'

  input.search(user_opts, search_opts, search_type.incsearch)
end

M.match_all = function(config)
  if not user_opts then
    M.setup({})
  end

  local search_opts = merge_config(config)
  search_opts._type = 'match_all'

  input.search(user_opts, search_opts, search_type.match_all)
end

M.simple = function(config)
  if not user_opts then
    M.setup({})
  end

  local search_opts = merge_config(config)
  search_opts._type = 'simple'

  input.search(user_opts, search_opts, search_type.simple)
end

M.replace = function(config)
  if not user_opts then
    M.setup({})
  end

  local search_opts = merge_config(config)
  search_opts._type = 'match_all'

  if search_opts.confirm == nil then
    search_opts.confirm = 'off'
  end

  if not utils.validate_confirm_mode(search_opts.confirm) then
    local msg = "[SearchBox replace] Invalid value for 'confirm' argument"
    vim.notify(msg, vim.log.levels.ERROR)
    return
  end

  local border_opts = {
    border = {
      text = {
        top = ' Replace ',
        bottom = ' 1/2 ',
        bottom_align = 'right'
      }
    }
  }

  local opts = utils.merge(user_opts, {popup = border_opts})
  input.search(opts, search_opts, search_type.replace)
end

return M

