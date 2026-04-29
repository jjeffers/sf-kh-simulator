#!/bin/sh
printf '\033c\033]0;%s\a' SFKH Simulator
base_path="$(dirname "$(realpath "$0")")"
"$base_path/kh.x86_64" "$@"
