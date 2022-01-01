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

There are four kinds of search:

* `incsearch`: Highlights the nearest match of your query as you type.

* `match_all`: Highlights all the matches in the buffer as you type. By default matches will stay highlighted after you submit your search. You can clear them with `:SearchBoxClear`. If you want the highlight to disapear after the input closes, add the `clear_matches` argument (more on this later).

* `simple`: Doesn't do anything as you type. No highlight, no moving the cursor around in realtime. It's only purpose is to execute a search.

* `replace`: Starts a multi-step input to search and replace. First input allows you to enter a pattern (search term). Second input will ask for the string that will replace the previous pattern.

## Usage

There is a command for each kind of search which can be used in a keybinding.

* **Lua Bindings**

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
vim.api.nvim_set_keymap(
  'x',
  '<leader>s',
  ':SearchBoxIncSearch visual_mode=true<CR>',
  {noremap = true}
)
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

You can tweak the behaviour of the search if pass any of these properties:

* `reverse`: Look for matches above the cursor.
* `exact`: Look for an exact match.
* `title`: Set title for the popup window.
* `prompt`: Set input prompt.
* `default_value`: Set initial value for the input.
* `visual_mode`: Search only in the recently selected text.

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
:SearchBoxMatchAll title=Match clear_matches=true -- I want to search this<CR>
```

In the example above `I want to search this` will become the initial value for the search input. This becomes useful when you want to use advance techniques to set the initial value of your search (I'll show you some examples later).

If you only going to set the initial value, meaning you're not going to use any of the other arguments, you can omit the `--`. This is valid, too.

```vim
:SearchBoxMatchAll I want to search this<CR>
```

### Lua api

In this case you'll be using lua functions of the `searchbox` module instead of commands. The arguments can be provided as a lua table.

```vim
:lua require('searchbox').match_all({title='Match All', clear_matches=true, default_value='I want to search this'})<CR>
```

### Examples

Make a reverse search, like the default `?`:

```vim
:SearchBoxIncSearch reverse=true<CR>
```

Make the highlight of `match_all` go away after submit.

```vim
:SearchBoxMatchAll clear_matches=true<CR>
```

Move to the nearest exact match without any fuss.

```vim
:SearchBoxSimple exact=true<CR>
```

Start a search and replace.

```vim
:SearchBoxReplace<CR>
```

Use the word under the cursor to begin search and replace. (Normal mode).

```vim
:SearchBoxReplace -- <C-r>=expand('<cword>')<CR><CR>
```

Look for the exact word under the cursor.

```vim
:SearchBoxMatchAll exact=true -- <C-r>=expand('<cword>')<CR><CR>
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

This are the defaults.

```lua
require('searchbox').setup({
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

- `popup` is passed directly to `nui.popup`. You can check the valid keys in their documentation: [popup.options](https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/popup#options)

- `hooks` must be functions. They will be executed during the "lifecycle" of the input.

*before_mount* and *after_mount* receive the instance of the input, so you can do anything with it.

*on_done* it's executed after the search is finished. In the case of a successful search it gets the value submitted and the type of search as arguments. When doing a search and replace, it gets executed after the last substitution takes place. In case the search was cancelled, the first argument is `nil` and the second argument is the type of search.

## Caveats

It's very possible that I can't simulate every feature of the built-in search (`/` and  `?`).

## Contributing

Bug fixes are welcome. Everything else? Let's discuss it first.

If you want to improve the UI it will be better if you contribute to [nui.nvim](https://github.com/MunifTanjim/nui.nvim).

## Support

If you find this tool useful and want to support my efforts, [buy me a coffee ☕](https://www.buymeacoffee.com/vonheikemen).

[![buy me a coffee](https://res.cloudinary.com/vonheikemen/image/upload/v1618466522/buy-me-coffee_ah0uzh.png)](https://www.buymeacoffee.com/vonheikemen)


