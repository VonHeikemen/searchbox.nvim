# Searchbox

Start your search from a more comfortable place, say the upper right corner?

![Neovim in a terminal, displaying a wonderful searchbox](https://res.cloudinary.com/vonheikemen/image/upload/v1637716458/other/Captura_de_pantalla_de_2021-11-23_21-09-14.png)

> This plugin is very much a work in progress.

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

There are three kinds of search:

* `incsearch`: Highlights the nearest match of your query as you type.

* `match_all`: Highlights all the matches in the buffer as you type. By default matches will stay highlighted after you submit your search. You can clear them with `:SearchBoxClear`. If you want the highlight to disapear after the input closes, add the `clear_matches` argument (more on this later).

* `simple`: Doesn't do anything as you type. No highlight, no moving the cursor around in realtime. It's only purpose is to execute a search.

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

### Search function arguments

You can tweak the behaviour of the search if you pass a table with any of these keys:

* `reverse`: Look for matches above the cursor.
* `exact`: Look for an exact match.
* `title`: Set title for the popup window.

The *match_all* search also accepts:

* `clear_matches`: Get rid of the highlight after the search is done.

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
    before_mount = function() end,
    after_mount = function() end
  }
})
```

- `popup` is passed directly to `nui.popup`. You can check the valid keys in their documentation: [popup.options](https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/popup#options)

- `hooks` must be functions. They will be executed during the "lifecycle" of the input.

`before_mount` and `after_mount` recieve the instance of the input, so you can do anything with it.

## Roadmap

* Add search and replace component.

## Caveats

It's very possible that I can't simulate every feature of the built-in search (`/` and  `?`).

Currently `incsearch()` uses `normal n` to navigate between matches, this will pollute your jumplist.

## Contributing

Bug fixes are welcome. Everything else? Let's discuss it first.

If you want to improve the UI it will be better if you contribute to [nui.nvim](https://github.com/MunifTanjim/nui.nvim).

## Support

If you find this tool useful and want to support my efforts, [buy me a coffee ☕](https://www.buymeacoffee.com/vonheikemen).

[![buy me a coffee](https://res.cloudinary.com/vonheikemen/image/upload/v1618466522/buy-me-coffee_ah0uzh.png)](https://www.buymeacoffee.com/vonheikemen)

