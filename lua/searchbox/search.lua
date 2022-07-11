local M = {}

local config = require('searchbox.config')
local input = require('searchbox.inputs')
local utils = require('searchbox.utils')
local merge = require('searchbox.utils.pure').merge
local search_types = require('searchbox.search-types')

local function do_search(search_type)
  return function(current_config)
    local search_opts = merge(config.search_defaults, current_config)

    input.search(config.get(), search_opts, search_type)
  end
end

M.simple = do_search(search_types.simple)
M.incsearch = do_search(search_types.incsearch)
M.match_all = do_search(search_types.match_all)

M.replace = function(current_config)
  local search_defaults = {
    exact = false,
    title = false,
    visual_mode = false,
    prompt = ' ',
    confirm = 'off',
    range = {-1, -1}
  }

  local search_opts = merge(config.search_defaults, merge(search_defaults, current_config))

  if not utils.validate_confirm_mode(search_opts.confirm) then
    error('(SearchBox replace) Invalid value for confirm argument')
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

  local opts = utils.merge(config.get(), {popup = border_opts})
  input.search(opts, search_opts, search_types.replace)
end

return M
