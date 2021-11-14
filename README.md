# nvim-launcher

A process manager for your dev-server and any other script you might need for your project.

NOTE: VERY early stage of development. Core functionality works, but is a bit cumbersome to use. Feel free to open issues to suggest improvements. Also expect things to change and break (aside from the documented top-level api)

## Installation

Developed against Neovim HEAD. It should work with the stable version, but your milage may vary.
We depend on [`nvim-lua/plenary.nvim`](https://github.com/nvim-lua/plenary.nvim) for async and other utilities.
Use your favourite package manager, for example [`packer.nvim`](https://github.com/wbthomason/packer.nvim):

```lua
require('packer').startup(function() 
  use {'RianFuro/nvim-launcher', requires = {'nvim-lua/plenary.nvim'}}
end)
```

## Setup

There's no setup to be called for now, but a `.setup` function exists as a kinda placeholder, so you can put that into your config to be future-proof:

```lua
require 'launcher'.setup()
```

Scripts are specific to a certain project so they are not defined in the global setup call. There is currently no *good* way to configure them automatically, but you can call `.extend` to set your managed scripts:

```lua
require 'launcher'.extend({
  test = {
    cmd = 'echo Hello, World!',
  },
  start = {
    cmd = 'npm start'
  }
})
```

If you allow sourcing `.nvimrc` files from the current directory you can put your script setup there to be sourced automatically.

Loading script configuration from a project local file, package.json, etc. is in the works.

## Usage

For now there's a lua-api and an interactive buffer. Vim-command-api is also in the works.

```lua
require 'launch'.toggle_control_panel()
```
toggles the interactive buffer. Currently there's only one key bound:
- `<CR>`: Toggle the process under the cursor.


```lua
local launch = require 'launch'
```

All the functionality can also be accessed programmatically via the top-level `launch` module:

- Start a proces:
  ```lua
  launch('<script-name>')
  -- OR
  launch.start('<script-name>')
  ```

- Stop a process:
  ```lua
  launch.stop('<script-name>')
  ```

- Restart a process:
  ```lua
  launch.restart('<script-name>')
  ```

- Get a handle to a script:
  ```lua
  local handle = launch.get('<script-name>')

  -- the handle also exposes start/stop functions:
  handle.start()
  handle.stop()

  -- you can also block until the script completes:
  local result = handle.sync()
  ```

- Get all configured scripts (as handles):
  ```lua
  launch.all()
  ```

Notably absent currently is to actually get to the log output of any script. This is basically next on the TODO-list, until then you have to get the buffer from the script handle and open it:

```lua
vim.cmd('b'..launch.get('<script-name>').bufnr)
```

These are channel-controlled terminal buffers, so they follow automatically as long as the cursor is at the bottom, but can otherwise be navigated freely.
Note that manually deleting the buffer is currently undefined behavior.
