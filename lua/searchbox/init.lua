local M = {}

local config = require('searchbox.config')
local utils = require('searchbox.utils')
local search = require('searchbox.search')

M.setup = config.setup

M.clear_matches = function()
  utils.clear_matches(vim.fn.bufnr('%'))
end

for export, fn in ipairs(search) do
  M[export] = fn
end

return M
