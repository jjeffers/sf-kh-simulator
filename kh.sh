#!/bin/sh
printf '\033c\033]0;%s\a' Hex Space Combat
base_path="$(dirname "$(realpath "$0")")"
"$base_path/kh.x86_64" "$@"
