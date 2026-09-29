#!/bin/sh
set -eu
cd "$(dirname "$0")"
make clean
make
printf 'Built %s\n' "$(pwd)/snake.nes"
