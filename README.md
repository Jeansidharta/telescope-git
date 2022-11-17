# Telescope and Git integrations

This was created because I felt the default telescope git integrations were a little lacking. This is currently a personal project, but could theoreticaly be used in other setups.

## Requirements

- [Telescope](https://github.com/nvim-telescope)
- [Git](https://git-scm.com/) instaled in your system
- [plenary](https://github.com/nvim-lua/plenary.nvim)

## Install

You can use your favorite plugin manager. Some examples:

- Packer: `use { 'Jeansidharta/telescope-git' }`
- Vim plug: `Plug 'Jeansidharta/telescope-git'`

After that, don't forget to add this extension to Telescope, using the command

```
require('telescope').load_extension('telescope_git')
```

### Configuration

There are currently no configuration options

### Usage

The following commands are available:

- `Telescope telescope_git all_branches`: Lists all branches of the current buffer.
