# hfd-terminal.nvim

A lightweight Neovim terminal manager with floating and horizontal layouts, multiple sessions, and command execution support.

## Features

- Floating and horizontal terminal layouts.
- Multiple terminal sessions with individual IDs.
- Automatic working directory detection based on the current file.
- Send commands directly to active or background sessions.
- Session listing with visibility and active session status.

## Installation (lazy.nvim)

```lua
{
    "PyNetCoder/hfd-terminal.nvim",
    cmd = { "HfdTerminal", "HfdTerminalList" },
    keys = {
        {
            "<leader>tt",
            "<cmd>HfdTerminal<CR>",
            desc = "Toggle Terminal",
        },
        {
            "<leader>tl",
            "<cmd>HfdTerminalList<CR>",
            desc = "List Terminal Sessions",
        },
    },
    opts = {
        layout = "float",
        height = 15,
        shell = vim.o.shell,
    },
    config = function(_, opts)
        require("hfd.terminal").setup(opts)
    end,
}

## Commands

| Command | Description |
|---|---|
| `:HfdTerminal` | Toggle the active terminal session. |
| `:HfdTerminal <ID>` | Toggle a specific terminal session. |
| `:HfdTerminal C <command>` | Execute a command in the active terminal. |
| `:HfdTerminal C <ID> <command>` | Execute a command in a specific terminal session. |
| `:HfdTerminalList` | List active and background terminal sessions. |