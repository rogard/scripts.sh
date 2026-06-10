#!/usr/bin/env bash

#===============================================================================
#  clone.sh — clones a given file to a uniquely named file
#
#  Author: Erwann Rogard
#  License: GPL 3.0 (https://www.gnu.org/licenses/gpl-3.0.en.html)
#
#  Usage:
#    ./clone.sh [option] <file>
#  Option:
#    --dry-run=true|false
#    --extension=<extension>
#    --target-dir=<directory>
#  Output
#    <target file>
#===============================================================================

set -euo pipefail
# Reminder:
# `true|false` to be inside a subshell `()` o/w `set -e` will stop execution.

# --- CONFIGURATION ------------------------------------------------------------
fallback_default_dir="$HOME/1nbox"
fallback_clone_log="$HOME/.local/share/clone.log"
fallback_trash_dir="$HOME/.local/share/Trash/files"

array=('default_dir' 'clone_log' 'trash_dir')

for name in "${array[@]}"; do
    fallback_var="fallback_${name}"
    [[ -z "${!name-}" ]] && declare "$name"="${!fallback_var}"
done

fallback_recurse_fun() {
    exec "${BASH_SOURCE[0]}" \
         --dry-run="$dryrun_flag" \
         --extension="$target_ext" \
         --target-dir="$target_dir" \
         "$source_file" \
         "$@"
}

fallback_unique_fun() {
    local var
    var=$(mktemp -u)
    echo "${var##*/tmp.}"
}

fallback_msg_fun() {
    local msg status symb
    status="$1"
    msg="$2"

    case "$status" in
        0) symb=✅ ;;
        *) symb=❌ ;;
    esac

    printf '%s %s\n' "$symb" "$msg" >&2
}

# ------------------------------------------------------------------------------

array=('default_dir' 'trash_dir')

for name in "${array[@]}"; do
    fallback_var="fallback_${name}"
    [[ -z "${!name-}" ]] && declare "$name"="${!fallback_var}"
done

array=('msg_fun' 'recurse_fun' 'unique_fun')

for name in "${array[@]}"; do
    fallback_fun="fallback_${name}"
    if ! declare -F "$name" >/dev/null && declare -F "$fallback_fun" >/dev/null; then
        eval "$(declare -f "$fallback_fun" | sed "s/^$fallback_fun/$name/")"
    fi
done

dryrun_flag='false'
target_ext=''
target_dir=''
args=()

while (( $# > 0 )); do
    case "$1" in
        --dry-run=*)
            dryrun_flag="${1#*=}"
            [[ "$dryrun_flag" =~ ^(true|false)$ ]] || {
                msg_fun "$?" "invalid argument $dryrun_flag"
                exit 1
            }
            shift
            ;;
	--target-dir=*)
            target_dir="${1#*=}"
            target_dir="${target_dir/#\~/$HOME}"
            shift
	    ;;
        --extension=*)
            target_ext="${1#*=}"
            shift
            ;;
        --*)
            echo "$(false; msg_fun "$?" "unknown option: $1")"
            exit 1
            ;;
        *)
            args+=("$1")
            shift
            ;;
    esac
done

[[ -n "$target_dir" ]] || target_dir="$default_dir"

count="${#args[@]}"
(( count == 1 )) || {
    msg_fun "$?" "$(printf '%s positional arguments' "$count")"
    exit 1
}

source_file="${args[0]}"

if [[ -z "$target_ext" && "$source_file" == *.* ]]; then
    target_ext="${source_file##*.}"
    recurse_fun "$@" || {
        msg_fun "$?" "failed to recurse"
        exit 1
    }
fi

[[ -f "$source_file" ]] || {
    msg_fun "$?" "$source_file is not a file"
    exit 1
}

if [[ ! -d "$target_dir" ]]; then
    msg='Create unique directory %s? [y/n] '
    read -r -p "$(printf "$msg" "$target_dir")" answer

    case "$answer" in
        [yY]*)
            mkdir -p "$target_dir" || {
                msg_fun "$?" "$(printf 'failed to create directory %s' "$target_dir")"
                exit 1
            }
            recurse_fun "$@"
            ;;
        *)
            false
            msg_fun "$?" 'Abort'
            exit 1
            ;;
    esac
fi

if [[ ! -f "$clone_log" ]]; then
    msg='Create unique log %s? [y/n] '
    read -r -p "$(printf "$msg" "$clone_log")" answer

    case "$answer" in
        [yY]*)
            touch "$clone_log" || {
                msg_fun "$?" "$(printf 'failed to create file %s' "$clone_log")"
                exit 1
            }
            recurse_fun "$@"
            ;;
        *)
            false
            msg_fun "$?" 'Abort'
            exit 1
            ;;
    esac
fi

target_file="${target_dir%/}/"
target_file+="$(unique_fun)"

[[ -z "$target_ext" ]] || target_file+=".${target_ext}"

# --- SIDE EFFECT --------------------------------------------------------------

msg_format=$(printf 'copy %s to %s' "$source_file" "$target_file")

[[ "$dryrun_flag" == 'true' ]] \
    || cp "$source_file" "$target_file" \
    && printf '%s\t%s\n' "$source_file" "$target_file" >> "$clone_log" \
    || {
        msg_fun "$?" "$msg_format"
        exit 1
    }

msg_format=$(printf 'move %s to %s' "$source_file" "$trash_dir")
trash_path="${trash_dir%/}/$(basename "$source_file")"

[[ "$dryrun_flag" == 'true' ]] \
    || mv "$source_file" "$trash_path" \
    || {
        msg_fun "$?" "$msg_format"
        exit 1
    }

echo "$target_file"

exit 0
