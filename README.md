# open.sh

Small CLI tool to open any project on your system.

## Installation

Simply download the file `open.sh` from this repository to a location within your `$PATH`.

For the lazy people out there, you can run the command below to install it automatically to `/usr/local/bin/open`.

```sh
curl https://raw.githubusercontent.com/Unoqwy/open.sh/master/install.sh | sudo bash -s
```

## Usage

```sh
# Create a new preset called 'vscode' and edit it in vim
EDITOR=vim open -p new vscode # insert `code "$1"` in the opened script

# Go to $HOME/my-project and bind the dir to a project called 'myproj' with preset 'vscode'
cd ~/my-project
open -b myproj vscode

# Alternatively, you can use the '-d' argument to avoid changing working directory
open -b myproj vscode -d ~/my-project

# Open project
open myproj # calls `code "$HOME/my-project"`
```

## Integration example

Using `open` from the CLI is nice but depending on your use case, it might be more convenient to open a prompt and bind it to a global system keybinding. Here's an example to open such a prompt using rofi:

```sh
#!/bin/sh
OSH_BIN="${OSH_BIN:-"open"}"
result=$("$OSH_BIN" -l | sort | rofi -dmenu -i -l 10 -p "Projects")
[[ -n $result ]] && "$OSH_BIN" "$result"
```

You could even pair it with a tool to sort by recency. If that sounds interesting to you, check out [this script](https://github.com/Unoqwy/dotfiles/blob/master/roles/workflow/misctools/bins/histrec) and [an adjusted version](https://github.com/Unoqwy/dotfiles/blob/master/roles/desktop/qde/bins/open-proj) of the rofi example above.

