#!/usr/bin/env bash

# Automatically kills a process when STDIN is closed.
#
# This is necessary to prevent zombie processes which occur when the VM dies.
#
# https://hexdocs.pm/elixir/1.14/Port.html#module-zombie-operating-system-processes

# Spawn the program.
exec "$@" &
pid1=$!

# Silence warnings from here on.
exec >/dev/null 2>&1

# Kill running program when STDIN closes.
exec 0<&0 $(
  while read; do :; done
  kill -KILL $pid1
) &
pid2=$!

# Clean up.
wait $pid1
ret=$?
kill -KILL $pid2
exit $ret
