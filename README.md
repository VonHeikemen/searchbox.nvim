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

## Usage

Right now there is only type of search: `incsearch`. Call it from a keybinging and do your thing.

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

So if you wanted to make a reverse search like the default `?`, you'll do this:

```lua
<cmd>lua require("searchbox").incsearch({reverse = true})<CR>
```

## Configuration

If you want to change anything from the `ui` or add a "hook" you can use `.setup()`.

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
* Add other types of search.

## Caveats

It's very possible that I can't simulate every feature of the built-in search (`/` and  `?`).

Currently `incsearch()` uses `normal n` to navigate between matches, this will pollute your jumplist.

## Contributing

Bug fixes are welcome. Everything else? Let's discuss it first.

If you want to improve the UI it will be better if you contribute to [nui.nvim](https://github.com/MunifTanjim/nui.nvim).

## Support

If you find this tool useful and want to support my efforts, [buy me a coffee ☕](https://www.buymeacoffee.com/vonheikemen).

[![buy me a coffee](https://res.cloudinary.com/vonheikemen/image/upload/v1618466522/buy-me-coffee_ah0uzh.png)](https://www.buymeacoffee.com/vonheikemen)

