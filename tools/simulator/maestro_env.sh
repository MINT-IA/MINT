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
# This script sets JAVA_HOME + PATH from brew's OpenJDK and then exec's
# the requested maestro command. Prefer OpenJDK 21: Maestro 2.5.1 currently
# loads Jansi native code during CLI bootstrap, and the Homebrew rolling
# OpenJDK 25 path can hang before even `--version` returns on this Mac mini.
#
# Usage :
#   bash tools/simulator/maestro_env.sh test flows/julien_swiss.yaml
#   bash tools/simulator/maestro_env.sh --version
#
# Why not just `eval $(brew shellenv)` ? — brew shellenv doesn't add keg-only
# OpenJDK to PATH. We must set JAVA_HOME explicitly to its libexec path.

set -euo pipefail

if [ -d "/opt/homebrew/opt/openjdk@21" ]; then
  OPENJDK_FORMULA="/opt/homebrew/opt/openjdk@21"
elif [ -d "/opt/homebrew/opt/openjdk" ]; then
  OPENJDK_FORMULA="/opt/homebrew/opt/openjdk"
else
  echo "ERROR: brew openjdk not installed. Run: brew install openjdk@21" >&2
  exit 1
fi
if [ ! -x "$HOME/.maestro/bin/maestro" ]; then
  echo "ERROR: Maestro CLI not installed. Run: curl -fsSL https://get.maestro.mobile.dev | bash" >&2
  exit 1
fi

export JAVA_HOME="$OPENJDK_FORMULA/libexec/openjdk.jdk/Contents/Home"
export PATH="$OPENJDK_FORMULA/bin:$PATH"
export MAESTRO_CLI_NO_ANALYTICS=1
export MAESTRO_DISABLE_UPDATE_CHECK=true

# Jansi scans java.io.tmpdir during CLI bootstrap. On this Mac mini the default
# macOS TMPDIR can be large enough to make even `maestro --version` hang.
MINT_MAESTRO_TMP_ROOT="${MINT_MAESTRO_TMP_ROOT:-/tmp/mint-maestro-runtime}"
MINT_MAESTRO_JAVA_TMPDIR="${MINT_MAESTRO_JAVA_TMPDIR:-$MINT_MAESTRO_TMP_ROOT/java}"
MINT_MAESTRO_JANSI_TMPDIR="${MINT_MAESTRO_JANSI_TMPDIR:-$MINT_MAESTRO_TMP_ROOT/jansi}"
mkdir -p "$MINT_MAESTRO_JAVA_TMPDIR" "$MINT_MAESTRO_JANSI_TMPDIR"
export JAVA_OPTS="-Djava.io.tmpdir=$MINT_MAESTRO_JAVA_TMPDIR -Djansi.tmpdir=$MINT_MAESTRO_JANSI_TMPDIR -Djansi.graceful=true ${JAVA_OPTS:-}"

if [ "$(uname)" = "Darwin" ]; then
  case "$(uname -m)" in
    arm64) JANSI_ARCH="arm64" ;;
    x86_64) JANSI_ARCH="x86_64" ;;
    *) JANSI_ARCH="" ;;
  esac

  if [ -n "$JANSI_ARCH" ]; then
    JANSI_ROOT="$HOME/.maestro/native"
    JANSI_LIB="$JANSI_ROOT/Mac/$JANSI_ARCH/libjansi.jnilib"
    JANSI_JAR="$HOME/.maestro/lib/jansi-2.4.1.jar"

    if [ ! -x "$JANSI_LIB" ] && [ -f "$JANSI_JAR" ]; then
      JANSI_TMP="$(mktemp -d "$MINT_MAESTRO_JANSI_TMPDIR/mint-jansi-extract.XXXXXX")"
      mkdir -p "$(dirname "$JANSI_LIB")"
      (
        cd "$JANSI_TMP"
        jar xf "$JANSI_JAR" "org/fusesource/jansi/internal/native/Mac/$JANSI_ARCH/libjansi.jnilib"
      )
      cp "$JANSI_TMP/org/fusesource/jansi/internal/native/Mac/$JANSI_ARCH/libjansi.jnilib" "$JANSI_LIB"
      chmod 755 "$JANSI_LIB"
      xattr -d com.apple.quarantine "$JANSI_LIB" 2>/dev/null || true
      xattr -d com.apple.provenance "$JANSI_LIB" 2>/dev/null || true
      rm -rf "$JANSI_TMP"
    fi

    if [ -x "$JANSI_LIB" ]; then
      export JAVA_OPTS="-Dlibrary.jansi.path=$JANSI_ROOT ${JAVA_OPTS:-}"
    fi
  fi
fi

exec "$HOME/.maestro/bin/maestro" "$@"
