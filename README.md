# nvim-launcher

A process manager for your dev-server and any other script you might need for your project.

**NOTE**: early stage of development. Core functionality works, but I'm still figuring out a good UX, so the UI and keybindings might change abruptly. If you still decide to use this plugin as-is, be sure to check back to the README for potential changes when updating. 

Feel free to open issues to suggest improvements. Also expect things to change and break (aside from the documented top-level api)

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

Call `setup` to initialize the package. This will search for scripts in various sources of your project:

```lua
require 'launcher'.setup()
```

Scripts are currently searched for in the following locations:
- package.json


There is currently no *good* way to manually add scripts on a per-project basis, but you can call `.extend` to add to your managed scripts:

```lua
require 'launcher'.extend({
  {
    name = 'test',
    cmd = 'echo Hello, World!',
  },
  {
    name = 'start',
    cmd = 'npm start'
  }
})
```

If you allow sourcing `.nvimrc` files from the current directory you can put your script setup there to be sourced automatically.

Loading script configuration from a project local file and other sources is in the works.

## Usage

For now there's a lua-api and an interactive buffer. Vim-command-api is also in the works.

```lua
require 'launch'.toggle_control_panel()
```
toggles the interactive buffer. Moving the cursor over an entry will show the current output of that script on the right. 
Current keybindings:
- `q`: Close the control panel.
- `<CR>`: Toggle the process under the cursor.
- `<C-]>`/`<C-w>l`: Jump to the currently shown output buffer. Use `<C-o>`/`<C-w>h` to jump back.


All the functionality can also be accessed programmatically via the top-level `launch` module:
```lua
local launch = require 'launch'
```

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

- Open output buffer for a script:
  ```lua
  launch.get('<script-name>').open_output_buffer()
  ```

  This uses `sbuffer` internally and appends an optional argument before,
  allowing the split position to be modified:

  ```lua
  launch.get('<script-name>').open_output_buffer('vert')
  ```

  These are channel-controlled terminal buffers, so they follow automatically
  as long as the cursor is at the bottom, but can otherwise be navigated freely.
  Note that manually deleting the buffer is currently undefined behavior.
