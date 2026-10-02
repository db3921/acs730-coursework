#!/usr/bin/env bash
set -euo pipefail

if [ "$(whoami)" = "root" ]; then
  echo "Running as root"
fi

echo "Hello from lab 3"
