#!/usr/bin/env bash
# vim:fdm=marker

## Bash options {{{
set -o errexit
## }}}

BIN="$(basename "$0")"
OSH_DIR="${OSH_DIR:-"$HOME/.config/osh"}"

## Vars validation {{{
# $1: var name
_validate_dir() {
    if [[ -z "${!1}" ]]; then
        echo "\$$1 must not be empty"
        return 1
    elif [[ "${!1}" != *"/" ]]; then
        IFS= read -r "$1" <<<"${!1}/"
    fi

    if [[ -e "${!1}" ]]; then
        if [[ ! -d "${!1}" ]]; then
            echo "\$$1 points to a file that isn't a directory"
            return 1
        fi
    else
        mkdir -p "${!1}"
    fi
}

_validate_dir "OSH_DIR"
## }}}

## Utils {{{
# $1: file
_edit_file() {
    if [[ -z $EDITOR ]]; then
        echo "No known text editor found, please set the \$EDITOR variable"
        return 1
    else
        "$EDITOR" "$1"
    fi
}
## }}}

## Projects {{{
_PROJ_MAP_FILE="${OSH_DIR}projects"

# $1: project name
_osh_proj_get() {
    if [[ -z "$1" ]]; then
        return 1
    fi
}

_osh_proj_load_map() {
    declare -g -A projects
    if [[ ! -f $_PROJ_MAP_FILE ]]; then
        return
    fi

    while read proj; do
        if [[ -z $proj || $proj == "#"* ]]; then
            continue
        fi
        IFS=";" read -r _name _preset _path <<< "$proj"
        projects[$_name,0]=$_preset
        projects[$_name,1]=$_path
    done < "$_PROJ_MAP_FILE"
}

# $1: project name
# $2: preset
# $3: path
_osh_proj_bind() {
    if [[ -z "$1" || -z "$2" || -z "$3" ]]; then
        return 1
    fi

    if [[ ! -f $_PROJ_MAP_FILE ]]; then
        touch "$_PROJ_MAP_FILE"
    fi
    local _entry="$1;$2;$3"
    local updated=$(sed -i "s|^$1;.*\$|$_entry|w /dev/stdout" "$_PROJ_MAP_FILE")
    if [[ -z $updated ]]; then
        echo "$_entry" >> "$_PROJ_MAP_FILE"
    fi
}
## }}}

## Presets {{{
_PRESETS_DIR="${OSH_DIR}presets"

# $1: preset name
_osh_preset_create() {
    if [[ -z "$1" ]]; then
        return 1
    fi

    _validate_dir "_PRESETS_DIR"
    local file=$(_osh_preset_file "$1")
    if [[ -f $file ]]; then
        echo "Preset '$1' already exists"
        return 0
    elif [[ -e $file ]]; then
        echo "Polluted preset file '$file'!"
        return 1
    fi
    before=$(cat <<END
#!/bin/sh
# This script will be executed to open workspaces of preset '$1'.
# \$1 is the project dir/file, and the shebang can be changed.
# NB: Exit without making changes to abort preset creation.
END
    )
    echo "$before" > "$file"
    _edit_file "$file"
    if [[ $before == $(cat "$file") ]]; then
        rm "$file"
        echo "Preset script left untouched, creation aborted"
        return 1
    else
        chmod +x "$file"
        echo "Preset '$1' created"
    fi
}

# $1: preset name
_osh_preset_file() {
    if [[ -z "$1" ]]; then
        return 1
    fi

    echo "$_PRESETS_DIR/$1"
}

# $1: preset name
_osh_preset_check() {
    local _preset="$1"
    if [[ -z "$_preset" ]]; then
        echo "Preset name cannot be empty"
        return 1
    fi

    local _preset_file=$(_osh_preset_file "$_preset")
    if [[ -f "$_preset_file" ]]; then
        if [[ -x "$_preset_file" ]]; then
            return 0
        else
            echo "Preset '$_preset' is invalid: its file is not executable"
            return 1
        fi
    else
        echo "Preset '$_preset' does not exist"
        return 1
    fi
}
## }}}

## Main {{{
### Manage presets {{{
_main_presets() {
    local _action="$1"
    local _preset="$2"
    _req_name() {
        if [[ -z $_preset ]]; then
            echo "Usage: $BIN -p $_action <name>"
            return 1
        fi
    }

    case $_action in
        l|list)
            echo "Presets:"
            for file in "$_PRESETS_DIR/"*; do
                local found=$(basename "$file")
                echo "* $found"
            done
            ;;
        n|new)
            _req_name
            _osh_preset_create "$_preset"
            ;;
        e|edit)
            _req_name
            local _preset_file=$(_osh_preset_file "$_preset")
            if [[ -f $_preset_file ]]; then
                echo "Opening preset '$_preset' in editor.."
                _edit_file "$_preset_file"
                if [[ ! -x $_preset_file ]]; then
                    chmod +x "$_preset_file"
                fi
            else
                echo "Preset '$_preset' does not exist"
                return 1
            fi
            ;;
        d|del|delete)
            _req_name
            local _preset_file=$(_osh_preset_file "$_preset")
            if [[ -f $_preset_file ]]; then
                rm "$_preset_file"
                echo "Preset '$_preset' deleted"
            else
                echo "Preset '$_preset' does not exist"
                return 1
            fi
            ;;
        *)
            echo "Usage: $BIN -p list OR $BIN -p new/edit/del <name>"
            exit 1
            ;;
    esac
}
### }}}

### Bind project {{{
_main_bind() {
    _send_usage() {
        echo "Usage: $BIN -b <name> <preset> [-f <file> | -d <dir>]"
        echo "Omitting '-f' and '-d' will default to current working directory."
    }

    local _name="$1"
    local _preset="$2"
    if [[ -z $_name || -z $_preset ]]; then
        _send_usage
        return 1
    fi

    local _path
    case "$3" in
        "")
            _path=$(readlink -m .)
            ;;
        -f|--file)
            _path=$(readlink -m "$4")
            if [[ ! -f "$_path" ]]; then
                echo "Path given to '-f' is not a file"
                return 1
            fi
            ;;
        -d|--dir)
            _path=$(readlink -m "$4")
            if [[ ! -d "$_path" ]]; then
                echo "Path given to '-d' is not a directory"
                return 1
            fi
            ;;
        *)
            echo "Invalid target argument:"
            _send_usage
            return 1
            ;;
    esac

    if _osh_preset_check "$_preset"; then
        _osh_proj_bind "$_name" "$_preset" "$_path"
        echo "Project '$_name' bound to preset '$_preset'"
    fi
}
### }}}

### List projects {{{
_main_list_proj() {
    # TODO: human formatting (but keep machine readable lines when passing to pipe)
    _osh_proj_load_map
    for key in "${!projects[@]}"; do
        if [[ $key == *",0" ]]; then
            echo "${key::-2}"
        fi
    done
}
### }}}

### Open project {{{
_main_open() {
    _osh_proj_load_map
    local _name=$1
    if [[ -v 'projects[$_name,0]' && -v 'projects[$_name,1]' ]]; then
        local _preset=${projects[$_name,0]}
        local _path=${projects[$_name,1]}
        local _preset_file=$(_osh_preset_file "$_preset")
        if [[ -f "$_preset_file" ]]; then
            if [[ -x "$_preset_file" ]]; then
                "$_preset_file" "$_path"
            else
                echo "Project configured, but its preset ('$_preset') is a non-executable file"
                exit 1
            fi
        else
            echo "Project configured, but its preset ('$_preset') does not exist"
            exit 1
        fi
    else
        echo "Project '$_name' not configured"
        exit 1
    fi
}
### }}}

case $1 in
    "")
        echo "Usage: $BIN <project> OR $BIN -p/-b/-l <..>"
        exit 1
        ;;
    -p|--preset|--presets)
        shift
        _main_presets $@
        ;;
    -b|--bind)
        shift
        _main_bind $@
        ;;
    -l|--list)
        _main_list_proj $@
        ;;
    -*)
        echo "Invalid argument! Allowed ones:"
        echo "* '$BIN -p' to manage presets"
        echo "* '$BIN -b' to bind a project"
        echo "* '$BIN -l' to list projects"
        exit 1
        ;;
    *)
        _main_open $@
        ;;
esac
## }}}
