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

With `vim-plug`

```vim
Plug 'MunifTanjim/nui.nvim'
Plug 'VonHeikemen/searchbox.nvim'
```

With `packer`.

```lua
use {
  'VonHeikemen/searchbox.nvim',
  requires = {
    {'MunifTanjim/nui.nvim'}
  }
}
```

### Types of search

There are four kinds of search:

* `incsearch`: Highlights the nearest match of your query as you type.

* `match_all`: Highlights all the matches in the buffer as you type. By default matches will stay highlighted after you submit your search. You can clear them with `:SearchBoxClear`. If you want the highlight to disapear after the input closes, add the `clear_matches` argument (more on this later).

* `simple`: Doesn't do anything as you type. No highlight, no moving the cursor around in realtime. It's only purpose is to execute a search.

* `replace`: Starts a multi-step input to search and replace. First input allows you to enter a pattern (search term). Second input will ask for the string that will replace the previous pattern.

## Usage

Each type of search is a lua function you can bind to a key. Example.

* **Lua Bindings**

```lua
vim.api.nvim_set_keymap(
  'n',
  '<leader>s',
  '<cmd>lua require("searchbox").incsearch()<CR>',
  {noremap = true}
)
```

* **Vimscript Bindings**

```vim
nnoremap <leader>s <cmd>lua require('searchbox').incsearch()<CR>
```

### Visual mode

In visual mode you'll need to add `<Esc>` at the beginning of the mapping and use `visual_mode = true` in the arguments.

In this mode the search is limited to the range set by the selected text. Similar to what the `substitute` command does in this case `:'<,'>s/this/that/g`.

* lua

```lua
vim.api.nvim_set_keymap(
  'x',
  '<leader>s',
  '<Esc><cmd>lua require("searchbox").incsearch({visual_mode = true})<CR>',
  {noremap = true}
)
```

* vimscript

```vim
xnoremap <leader>s <Esc><cmd>lua require("searchbox").incsearch({visual_mode = true})<CR>
```

### Search function arguments

You can tweak the behaviour of the search if you pass a table with any of these keys:

* `reverse`: Look for matches above the cursor.
* `exact`: Look for an exact match.
* `title`: Set title for the popup window.
* `prompt`: Set input prompt.
* `default_value`: Set initial value for the input.
* `visual_mode`: Search only in the recently selected text.

*match_all* search also accepts:

* `clear_matches`: Get rid of the highlight after the search is done.

*replace* search accepts:

* `confirm`: Ask the user to choose an action on each match. There are three possible values: `off`, `native` and `menu`. `off` disables the feature. `native` uses neovim's built-in confirm method. `menu` displays a list of possible actions below the match. Is worth mentioning `menu` will only show up if neovim's window is big enough, confirm type will fallback to "native" if it isn't.

Here are some examples:

Make a reverse search, like the default `?`:

```vim
<cmd>lua require("searchbox").incsearch({reverse = true})<CR>
```

Make the highlight of `match_all` go away after submit.

```vim
<cmd>lua require("searchbox").match_all({clear_matches = true})<CR>
```

Move to the nearest exact match without any fuss.

```vim
<cmd>lua require("searchbox").simple({exact = true})<CR>
```

Start a search and replace.

```vim
<cmd>lua require("searchbox").replace()<CR>
```

Use the word under the cursor to begin search and replace. (Normal mode).

```vim
<cmd>lua require('searchbox').replace({default_value = vim.fn.expand('<cword>')})<CR>
```

Use the selected text as a search term (needs visual mode):

> Due to limitations on the input, it can't handle newlines well or even the escape sequence \n. So whatever you have selected, must be one line.

```vim
y<cmd>lua require('searchbox').replace({default_value = vim.fn.getreg('"')})<CR>
```

Search and replace within the range of the selected text, and look for an exact match. (Needs to be mapped in visual mode)

```vim
<Esc><cmd>lua require("searchbox").replace({exact = true, visual_mode = true})<CR>
```

Confirm every match of search and replace

- Normal mode:

```vim
<cmd>lua require("searchbox").replace({confirm = 'menu'})<CR>
```

- Visual mode:

```vim
<Esc><cmd>lua require("searchbox").replace({confirm = 'menu', visual_mode = true})<CR>
```

### Default keymaps

Inside the input you can use the following keymaps:

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
    end
  }
})
```

- `popup` is passed directly to `nui.popup`. You can check the valid keys in their documentation: [popup.options](https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/popup#options)

- `hooks` must be functions. They will be executed during the "lifecycle" of the input.

`before_mount` and `after_mount` receive the instance of the input, so you can do anything with it.

## Caveats

It's very possible that I can't simulate every feature of the built-in search (`/` and  `?`).

## Contributing

Bug fixes are welcome. Everything else? Let's discuss it first.

If you want to improve the UI it will be better if you contribute to [nui.nvim](https://github.com/MunifTanjim/nui.nvim).

## Support

If you find this tool useful and want to support my efforts, [buy me a coffee ☕](https://www.buymeacoffee.com/vonheikemen).

[![buy me a coffee](https://res.cloudinary.com/vonheikemen/image/upload/v1618466522/buy-me-coffee_ah0uzh.png)](https://www.buymeacoffee.com/vonheikemen)

