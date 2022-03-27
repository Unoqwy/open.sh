#!/usr/bin/env bash
# vim:fdm=marker

## Bash options {{{
set -o errexit
## }}}

BIN="$0"
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
# \$1 is the project dir, and the shebang can be changed.
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
## }}}

## Main {{{
if [[ -z "$1" ]]; then
    echo "Invalid usage"
    exit 1
fi

### Manage presets {{{
_main_presets() {
    local action="$1"
    local preset="$2"
    _req_name() {
        if [[ -z $preset ]]; then
            echo "Usage: $BIN -p $action <name>"
            return 1
        fi
    }

    case $action in
        l|list)
            echo "Presets:"
            for file in "$_PRESETS_DIR/"*; do
                local found=$(basename "$file")
                echo "* $found"
            done
            ;;
        n|new)
            _req_name
            _osh_preset_create $preset
            ;;
        e|edit)
            _req_name
            # TODO
            ;;
        d|del|delete)
            _req_name
            # TODO
            ;;
        *)
            echo "Usage: $BIN -p list OR $BIN -p new/edit/del <name>"
            exit 1
            ;;
    esac
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
    -p|--preset|--presets)
        shift
        _main_presets $@
        ;;
    # TODO: o -r <proj> <preset> [dir]
    *)
        _main_open $@
        ;;
esac
## }}}
