# Searchbox

Start your search from a more comfortable place, say the upper right corner?

![Neovim in a terminal, displaying a wonderful searchbox](https://res.cloudinary.com/vonheikemen/image/upload/v1637716458/other/Captura_de_pantalla_de_2021-11-23_21-09-14.png)

Here's demo of search and replace component, and also *match_all* search.

[Search and replace with a multi-step input](https://user-images.githubusercontent.com/20980671/143466541-1374ab97-0601-44a5-ab85-dab1ed63ab41.mp4)

## Getting Started

Make sure you have [Neovim v0.5.1](https://github.com/neovim/neovim/releases/tag/v0.5.1) or greater.

### Dependencies

- [nui.nvim](https://github.com/MunifTanjim/nui.nvim)

### Installation

Use your favorite plugin manager. For example.

With `vim-plug`:

```vim
Plug 'MunifTanjim/nui.nvim'
Plug 'VonHeikemen/searchbox.nvim'
```

With `packer`:

```lua
use {
  'VonHeikemen/searchbox.nvim',
  requires = {
    {'MunifTanjim/nui.nvim'}
  }
}
```

With `paq`:

```lua
'VonHeikemen/searchbox.nvim';
'MunifTanjim/nui.nvim';
```
### Types of search

There are five kinds of inputs:

* `incsearch`: Highlights the nearest match of your query as you type.

* `match_all`: Highlights all the matches in the buffer as you type. By default the highlights will disappear after you submit your search. If you want them to stay set the argument `clear_matches` to `false` (more on this later).

* `simple`: Doesn't do anything as you type. No highlight, no moving the cursor around in realtime. It's only purpose is to execute a search.

* `replace`: Starts a multi-step input to search and replace. First input allows you to enter a pattern (search term). Second input will ask for the string that will replace the previous pattern.

* `replace_last`: Acts like the second input of `replace`. The string you enter on this input will be used to replace the previous search query in your history.

## Usage

There is a command for each kind of search which can be used in a keybinding.

* **Lua Bindings**

If using neovim 0.7 or greater.

```lua
vim.keymap.set('n', '<leader>s', ':SearchBoxIncSearch<CR>')
```

If you have neovim 0.6.1 or lower.

```lua
vim.api.nvim_set_keymap(
  'n',
  '<leader>s',
  ':SearchBoxIncSearch<CR>',
  {noremap = true}
)
```

* **Vimscript Bindings**

```vim
nnoremap <leader>s :SearchBoxIncSearch<CR>
```

They are also exposed as lua functions, so the following is also valid.

```vim
:lua require('searchbox').incsearch()<CR>
```

### Visual mode

To get proper support in visual mode you'll need to add `visual_mode=true` to the list of arguments.

In this mode the search area is limited to the range set by the selected text. Similar to what the `substitute` command does in this case `:'<,'>s/this/that/g`.

* Lua Bindings

```lua
vim.keymap.set('x', '<leader>s', ':SearchBoxIncSearch visual_mode=true<CR>')
```

* Vimscript Bindings

```vim
xnoremap <leader>s :SearchBoxIncSearch visual_mode=true<CR>
```

When using the lua api add `<Esc>` at the beginning of the binding.

```vim
<Esc>:lua require('searchbox').incsearch({visual_mode = true})<CR>
```

### Search arguments

You can tweak the behaviour of the search if you pass any of these properties:

* `reverse`: Look for matches above the cursor.
* `exact`: Look for an exact match.
* `title`: Set title for the popup window.
* `prompt`: Set input prompt.
* `default_value`: Set initial value for the input.
* `visual_mode`: Search only in the recently selected text.
* `show_matches`: If set to `true` it'll show number of matches in the input. If set to a string the pattern `{total}` will be replaced with the number of matches. If the pattern `{match}` is found it'll be replaced with the index of match under the cursor. You can set for example, `show_matches='[M:{match} T:{total}]'`. The default format of the message is `[{match}/{total}]`.
* `modifier`: Apply a "search modifier" at the beginning of the search pattern. It won't be visible in the search input. Possible values:
  - `ignore-case`: Make the search case insensitive. Applies the pattern \c.
  - `case-sensitive`: Make the search case sensitive. Applies the pattern \C.
  - `no-magic`: Act as if the option `nomagic` is used. Applies the pattern \M.
  - `magic`: Act as if the option `magic` is on. Applies the pattern \m.
  - `very-magic`: Anything that isn't alphanumeric has a special meaning. Applies the pattern \v.
  - `very-no-magic`: Only the backslash and the terminating character has special meaning. Applies the pattern \V.
  - `plain`: Is an alias for `very-no-magic`.
  - `disabled`: Is the default. Don't apply any modifier.
  - `:`: It acts as a prefix. Use it to add your own modifier to the search. Example, `:\C\V` will make the search `very-no-magic` and also case sensitive. See `:help /magic` to know more about possible patterns.

Other arguments are exclusive to one type of search.

For *match_all*:

* `clear_matches`: Get rid of the highlight after the search is done.

For *replace*:

* `confirm`: Ask the user to choose an action on each match. There are three possible values: `off`, `native` and `menu`. `off` disables the feature. `native` uses neovim's built-in confirm method. `menu` displays a list of possible actions below the match. Is worth mentioning `menu` will only show up if neovim's window is big enough, confirm type will fallback to "native" if it isn't.

### Command Api

When using the command api the arguments are a space separated list of key/value pairs. The syntax for the arguments is this: `key=value`.

```vim
:SearchBoxMatchAll title=Match exact=true visual_mode=true<CR>
```

Because whitespace acts like a separator between the arguments if you want to use it as a value you need to escape it, or use a quoted argument. If you want to use `Match All` as a title, these are your options.

```vim
:SearchBoxMatchAll title="Match All"<CR>
" or
:SearchBoxMatchAll title='Match All'<CR>
```

```vim
:SearchBoxMatchAll title=Match\ All<CR>
```

> Note that escaping is specially funny inside a lua string, so you might need to use `\\`.

Is worth mention that argument parsing is done manually inside the plugin. Complex escape sequences are not taken into account. Just `\"` and `\'` to avoid conflict in quoted arguments, and `\ ` to escape whitespace in a string argument without quotes.

Not being able to use whitespace freely makes it difficult to use `default_value` with this api, that's why it gets a special treatment. There is no `default_value` argument, instead everything that follows the `--` argument is considered part of the search term.

```vim
:SearchBoxMatchAll title=Match clear_matches=false -- I want to search this<CR>
```

In the example above `I want to search this` will become the initial value for the search input. This becomes useful when you want to use advance techniques to set the initial value of your search (I'll show you some examples later).

If you only going to set the initial value, meaning you're not going to use any of the other arguments, you can omit the `--`. This is valid, too.

```vim
:SearchBoxMatchAll I want to search this<CR>
```

### Lua api

In this case you'll be using lua functions of the `searchbox` module instead of commands. The arguments can be provided as a lua table.

```vim
:lua require('searchbox').match_all({title='Match All', clear_matches=false, default_value='I want to search this'})<CR>
```

### Examples

Make a reverse search, like the default `?`:

```vim
:SearchBoxIncSearch reverse=true<CR>
```

Make the highlight of `match_all` stay after submit. They can be cleared manually with the command `:SearchboxClear`.

```vim
:SearchBoxMatchAll clear_matches=false<CR>
```

Move to the nearest exact match without any fuss.

```vim
:SearchBoxSimple modifier=case-sensitive exact=true<CR>
```

Add your own modifier to the search pattern. Here we apply `case-sensitive` and `very-no-magic` together. This makes it so we don't need to escape characters like `*` or `.`.

```vim
:SearchBoxIncSearch modifier=':\C\V'<CR>
```

Start a search and replace.

```vim
:SearchBoxReplace<CR>
```

Use the word under the cursor to begin search and replace. (Normal mode).

```vim
:SearchBoxReplace -- <C-r>=expand('<cword>')<CR><CR>
```

Look for the word under the cursor.

```vim
:SearchBoxMatchAll exact=true -- <C-r>=expand('<cword>')<CR><CR>
```

Search and replace, but use the most recent query as the search term. This basically acts like the second input of `SearchBoxReplace`.

```vim
:SearchBoxReplaceLast<CR>
```

Use the selected text as a search term. (Visual mode):

> Due to limitations on the input, it can't handle newlines well. So whatever you have selected, must be one line. The escape sequence `\n` can be use in the search term but will not be interpreted on the second input of search and replace.

```vim
y:SearchBoxReplace -- <C-r>"<CR>
```

Search and replace within the range of the selected text, and look for an exact match. (Visual mode)

```vim
:SearchBoxReplace exact=true visual_mode=true<CR>
```

Confirm every match of search and replace.

- Normal mode:

```vim
:SearchBoxReplace confirm=menu<CR>
```

- Visual mode:

```vim
:SearchBoxReplace confirm=menu visual_mode=true<CR>
```

### Default keymaps

Inside the input you can use the following keymaps:

* `Alt + .`: Writes the content of the last search in the input.
* `Enter`: Submit input.
* `Esc`: Closes input.
* `Ctrl + c`: Close input.
* `Ctrl + y`: Scroll up.
* `Ctrl + e`: Scroll down.
* `Ctrl + b`: Scroll page up.
* `Ctrl + f`: Scroll page down.
* `Ctrl + g`: Go to previous match.
* `Ctrl + l`: Go to next match.

In the confirm menu (of search and replace):

* `y`: Confirm replace.
* `n`: Move to next match.
* `a`: Replace all matches.
* `q`: Quit menu.
* `l`: Replace match then quit. Think of it as "the last replace".
* `Enter`: Accept option.
* `Esc`: Quit menu.
* `ctrl + c`: Quit menu.
* `Tab`: Next option.
* `shift + Tab`: Previous option.
* `Down arrow`: Next option.
* `Up arrow`: Previous option.

The "native" confirm method:

* `y`: Confirm replace.
* `n`: Move to next match.
* `a`: Replace all matches.
* `q`: Quit menu.
* `l`: Replace match then quit.

## Configuration

If you want to change anything in the `UI` or add a "hook" you can use `.setup()`.

This is the default configuration.

```lua
require('searchbox').setup({
  defaults = {
    reverse = false,
    exact = false,
    prompt = ' ',
    modifier = 'disabled',
    confirm = 'off',
    clear_matches = true,
    show_matches = false,
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
    before_mount = function(input)
      -- code
    end,
    after_mount = function(input)
      -- code
    end,
    on_done = function(value, search_type)
      -- code
    end
  }
})
```

- `defaults` is a "global config", allows you to set some properties for all inputs. So you don't have to declare them using the command api or the lua api.

- `popup` is passed directly to `nui.popup`. You can check the valid keys in their documentation: [popup.options](https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/popup#options)

- `hooks` must be functions. They will be executed during the "lifecycle" of the input.

*before_mount* and *after_mount* receive the instance of the input, so you can do anything with it.

*on_done* it's executed after the search is finished. In the case of a successful search it gets the value submitted and the type of search as arguments. When doing a search and replace, it gets executed after the last substitution takes place. In case the search was cancelled, the first argument is `nil` and the second argument is the type of search.

### Custom keymaps

You can only modify the keymaps after the input is created, means you should do it in the `after_mount` hook.

These are the actions available in the input.

* `<Plug>(searchbox-close)`
* `<Plug>(searchbox-scroll-up)`
* `<Plug>(searchbox-scroll-down)`
* `<Plug>(searchbox-scroll-page-up)`
* `<Plug>(searchbox-scroll-page-down)`
* `<Plug>(searchbox-prev-match)`
* `<Plug>(searchbox-next-match)`
* `<Plug>(searchbox-last-search)`
* `<Plug>(searchbox-replace-step)`

Here is an example. If you wanted to "add support" for normal mode, you would do this.

```lua
after_mount = function(input)
  local opts = {buffer = input.bufnr}

  -- Esc goes to normal mode
  vim.keymap.set('i', '<Esc>', '<cmd>stopinsert<cr>', opts)

  -- Close the input in normal mode
  vim.keymap.set('n', '<Esc>', '<Plug>(searchbox-close)', opts)
  vim.keymap.set('n', '<C-c>', '<Plug>(searchbox-close)', opts)
end
```

If you are using Neovim 0.6.1 or lower replace `vim.keymap.set` with `vim.api.nvim_buf_set_keymap`.

```lua
vim.api.nvim_buf_set_keymap(input.bufnr, 'n', '<Esc>', '<Plug>(searchbox-close)', {noremap = false})
```

## Caveats

It's very possible that I can't simulate every feature of the built-in search (`/` and  `?`).

## Alternatives

* [romgrk/searchbox.nvim](https://github.com/romgrk/searchbox.nvim): Fork of searchbox.nvim with extra features, like fuzzy search and icons.

## Contributing

Bug fixes are welcome. Everything else? Let's discuss it first.

If you want to improve the UI it will be better if you contribute to [nui.nvim](https://github.com/MunifTanjim/nui.nvim).

## Support

If you find this tool useful and want to support my efforts, [buy me a coffee ☕](https://www.buymeacoffee.com/vonheikemen).

[![buy me a coffee](https://res.cloudinary.com/vonheikemen/image/upload/v1618466522/buy-me-coffee_ah0uzh.png)](https://www.buymeacoffee.com/vonheikemen)

