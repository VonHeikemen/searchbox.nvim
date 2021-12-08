local M = {}

local bool = function(value)
  local variants = {['true'] = true, ['false'] = false}
  return variants[value]
end

local str = function(value)
  if value == "''" or value == '""' then
    return ''
  end

  return value
end

local to_opts = {
  reverse = bool,
  exact = bool,
  visual_mode = bool,
  clear_matches = bool,
  title = str,
  prompt = str,
  confirm = str,
}

local get_default_value = function(index, args)
  local result = ''

  for i=index, #args, 1 do
    local chunk = args[i]
    if i == index then
      result = chunk
    else
      result = result .. ' ' .. chunk
    end
  end

  return result
end

local parse_options = function(args)
  local result = {}
  local index = 0
  for i=1, #args, 1 do
    index = i

    if args[i] == '--' then
      break
    end

    local parsed = vim.split(args[i], '=')

    if #parsed == 2 then
      local opt = parsed[1]
      local convert = to_opts[opt]

      if type(convert) == 'function' then
        result[parsed[1]] = convert(parsed[2])
      else
        if i == 1 then return {}, 1 end
      end
    else
      if i == 1 then return {}, 1 end
    end
  end

  return result, index + 1
end

M.run = function(search_type, line1, line2, count, args)
  local opts, index = parse_options(args)
  local search_term = get_default_value(index, args)

  opts.default_value = search_term
  if line2 == count then
    opts.range = {line1, line2}
  end

  require('searchbox')[search_type](opts)
end

return M

