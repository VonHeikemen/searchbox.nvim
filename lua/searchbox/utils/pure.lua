--
-- pure.lua
--

local M = {}

M.merge = function(defaults, override)
  return vim.tbl_deep_extend(
    'force',
    {},
    defaults,
    override or {}
  )
end

return M
