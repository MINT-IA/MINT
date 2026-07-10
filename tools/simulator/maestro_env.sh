#!/usr/bin/env bash
# tools/simulator/maestro_env.sh
#
# Phase 90 PERS-01 (v2.13) — Maestro CLI environment helper.
#
# Maestro CLI on macOS requires Java 17+. brew installs `maestro` as a
# Cask (the Studio GUI app at /Applications/Maestro.app), NOT the CLI.
# Per https://docs.maestro.dev/getting-started/installation, the CLI is
# installed via :
#   curl -fsSL "https://get.maestro.mobile.dev" | bash
# which lands at ~/.maestro/bin/maestro and needs a JAVA_HOME on PATH.
#
# This script sets JAVA_HOME + PATH from brew's openjdk and then exec's
# the requested maestro command. Reproducible across machines that have
# brew + openjdk installed (no sudo required ; brew openjdk lives in the
# user-writable /opt/homebrew/opt/openjdk).
#
# Usage :
#   bash tools/simulator/maestro_env.sh test flows/julien_swiss.yaml
#   bash tools/simulator/maestro_env.sh --version
#
# Why not just `eval $(brew shellenv)` ? — brew shellenv doesn't add
# openjdk to PATH ; it's a keg-only formula. We must set JAVA_HOME
# explicitly to its libexec path.

set -euo pipefail

if [ ! -d "/opt/homebrew/opt/openjdk" ]; then
  echo "ERROR: brew openjdk not installed. Run: brew install openjdk" >&2
  exit 1
fi
if [ ! -x "$HOME/.maestro/bin/maestro" ]; then
  echo "ERROR: Maestro CLI not installed. Run: curl -fsSL https://get.maestro.mobile.dev | bash" >&2
  exit 1
fi

export JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
export MAESTRO_CLI_NO_ANALYTICS=1

exec "$HOME/.maestro/bin/maestro" "$@"
