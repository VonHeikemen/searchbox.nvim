local M = {}

local bool = function(value)
  local variants = {['true'] = true, ['false'] = false}

  if variants[value] == nil and #value > 0 then
    return false
  end

  return variants[value]
end

local str = function(value)
  return value
end

local escape_space = function(value)
  if vim.endswith(value, '\\') then
    return value:sub(1, #value - 1) .. ' '
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
  modifier = str,
}

local parse_options = function(args)
  local res = {}
  for opt, fn in pairs(to_opts) do
    if args[opt] then
      res[opt] = fn(args[opt])
    end
  end

  return res
end

local quoted_arg = function(current_arg, all_args, quote)
  local pos = {all_args:find(current_arg)}
  local first_quote = pos[2] + 1
  local cursor = first_quote

  while true do
    local last_quote = all_args:find(quote, cursor)
    if last_quote == nil then
      local substr = all_args:sub(first_quote)
      return {substr:len(), substr}
    end

    local arg_value = all_args:sub(first_quote, last_quote - 1)

    if vim.endswith(arg_value, '\\') then
      cursor = last_quote + 1
    else
      return {last_quote, arg_value}
    end
  end
end

local parse_input = function(input)
  local cursor = 1
  local opts = {}
  local prev_arg = nil

  -- `--` means stop. If it's the first thing, don't parse anything
  if input:sub(1, 3) == '-- ' then
    opts.default_value = input:sub(4)
    return opts
  end

  local first_word = input:match('^([a-z_]+=)')

  -- If input doesn't begin with any known argument
  -- don't bother, just return input as `default_value`
  if first_word == nil or
    to_opts[first_word:sub(1, #first_word - 1)] == nil
  then
    opts.default_value = input
    return opts
  end

  while true do
    local section = input:sub(cursor)
    local section_end = section:find(' ')
    local is_last = section_end == nil
    local arg = nil

    if is_last then
      section_end = section:len()
      arg = section
    else
      section_end = section_end - 1
      arg = section:sub(1, section_end)
    end

    local split = vim.split(arg, '=')

    -- User said stop. We stop.
    if prev_arg == nil and split[2] == nil and split[1] == '--' then
      opts.default_value = input:sub(cursor + section_end + 1)
      return opts
    end

    -- This is an actual argument `key=val`
    if #split == 2 then
      prev_arg = nil

      -- Are we dealing with a quoted argument?
      local first_char = split[2]:sub(1, 1)
      if first_char == "'" or first_char == '"' then
        local res = quoted_arg(
          split[1] .. '=' .. first_char,
          input,
          first_char
        )
        cursor = res[1] + 2
        opts[split[1]] = res[2]
      else
        if vim.endswith(split[2], '\\') then
          prev_arg = split[1]
          opts[split[1]] = escape_space(split[2])
        else
          opts[split[1]] = split[2]
        end
        cursor = cursor + (section_end + 1)
      end
    else
      -- the previous section had the sequence `\\`
      -- so this is part of the argument value
      if prev_arg then
        local prev_val = escape_space(opts[prev_arg])
        local new_arg = escape_space(split[1])

        opts[prev_arg] = prev_val .. new_arg

        -- Make sure we don't end up here again if we don't need to
        if not vim.endswith(split[1], '\\') then
          prev_arg = nil
        end
      end

      cursor = cursor + (section_end + 1)
    end

    if is_last then
      break
    end

  end

  return opts
end

M.run = function(search_type, line1, line2, count, input)
  local raw_opts = parse_input(input)
  local opts = parse_options(raw_opts)

  if raw_opts.default_value then
    opts.default_value = raw_opts.default_value
  end

  if line2 == count then
    opts.range = {line1, line2}
  end

  require('searchbox')[search_type](opts)
end

return M

