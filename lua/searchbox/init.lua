local M = {}

local search_defaults = {
  reverse = false,
  exact = false,
  prompt = ' ',
  modifier = 'disabled',
  title = false,
  visual_mode = false,
  range = {-1, -1},
  show_matches = false,
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
      winhighlight = 'Normal:Normal,FloatBorder:FloatBorder',
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
  opts = opts or {}
  local u = user_opts.defaults
  return vim.tbl_deep_extend(
    'force',
    search_defaults,
    {
      reverse = u.reverse,
      exact = u.exact,
      prompt = u.prompt,
      modifier = u.modifier,
      clear_matches = u.clear_matches,
      confirm = u.confirm,
      show_matches = u.show_matches
    },
    opts
  )
end

M.setup = function(config)
  user_opts = vim.tbl_deep_extend('force', defaults, config)
end

M.clear_matches = function()
  require('searchbox.utils').clear_highlights(vim.fn.bufnr('%'))
end

M.incsearch = function(config)
  local input = require('searchbox.inputs')
  local search_type = require('searchbox.search-types')

  if not user_opts then
    M.setup({})
  end

  local search_opts = merge_config(config)
  search_opts._type = 'incsearch'

  input.search(user_opts, search_opts, search_type.incsearch)
end

M.match_all = function(config)
  local input = require('searchbox.inputs')
  local search_type = require('searchbox.search-types')

  if not user_opts then
    M.setup({})
  end

  local search_opts = merge_config(config)
  search_opts._type = 'match_all'

  if search_opts.clear_matches == nil then
    search_opts.clear_matches = true
  end

  input.search(user_opts, search_opts, search_type.match_all)
end

M.simple = function(config)
  local input = require('searchbox.inputs')
  local search_type = require('searchbox.search-types')

  if not user_opts then
    M.setup({})
  end

  local search_opts = merge_config(config)
  search_opts._type = 'simple'

  input.search(user_opts, search_opts, search_type.simple)
end

M.replace = function(config)
  local utils = require('searchbox.utils')
  local input = require('searchbox.inputs')
  local search_type = require('searchbox.search-types')

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

M.replace_last = function(config)
  local utils = require('searchbox.utils')
  local input = require('searchbox.inputs')
  local search_type = require('searchbox.search-types')

  if not user_opts then
    M.setup({})
  end

  local search_opts = merge_config(config)
  search_opts._type = 'replace-last'

  if search_opts.confirm == nil then
    search_opts.confirm = 'off'
  end

  if search_opts.show_matches then
    search_opts.show_matches = nil
  end

  if not utils.validate_confirm_mode(search_opts.confirm) then
    local msg = "[SearchBox replace] Invalid value for 'confirm' argument"
    vim.notify(msg, vim.log.levels.ERROR)
    return
  end

  local opts = vim.deepcopy(user_opts)

  if search_opts.title == false then
    opts.popup.border.text.top = ' Replace with '
  end

  input.search(opts, search_opts, search_type.replace_last)
end

return M

