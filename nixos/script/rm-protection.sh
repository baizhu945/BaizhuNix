#!/usr/bin/env bash

REAL_RM="@realRm@"

targets=()
for arg in "$@"; do
  case "$arg" in
    -*) ;;
    *)  targets+=("$arg") ;;
  esac
done

if [ ${#targets[@]} -eq 0 ]; then
  exec "$REAL_RM" "$@"
fi

if [ ${#targets[@]} -eq 1 ]; then
  msg="${targets[0]}"
else
  msg="${#targets[@]} items: ${targets[*]}"
fi

printf 'Do you really want to remove \e[1;31m%s\e[0m ?\n' "$msg" >&2
printf '[yes/N] ' >&2
read -r answer < /dev/tty

if [ "$answer" = "yes" ]; then
  exec "$REAL_RM" "$@"
else
  printf 'Cancelled.\n' >&2
  exit 1
fi
