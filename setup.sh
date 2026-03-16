#!/usr/bin/env bash
#
# setup.sh — System Design Mastery course setup
#
# Clones external dependencies into deps/:
#   - System Design Primer (textbook)
#   - Server Survival (browser game)
#
# Safe to run multiple times. Does not require sudo.

set -euo pipefail

DEPS_DIR="deps"
PRIMER_REPO="https://github.com/donnemartin/system-design-primer.git"
PRIMER_DIR="$DEPS_DIR/system-design-primer"
GAME_REPO="https://github.com/pshenok/server-survival.git"
GAME_DIR="$DEPS_DIR/server-survival"

# --- Check prerequisites ---

if ! command -v git &> /dev/null; then
    echo "Error: git is not installed."
    echo "Install git from https://git-scm.com/downloads and try again."
    exit 1
fi

# --- Create deps directory ---

mkdir -p "$DEPS_DIR"

# --- Clone System Design Primer ---

if [ -d "$PRIMER_DIR" ]; then
    echo "System Design Primer already exists at $PRIMER_DIR — skipping."
else
    echo "Cloning System Design Primer..."
    if git clone "$PRIMER_REPO" "$PRIMER_DIR"; then
        echo "System Design Primer cloned successfully."
    else
        echo "Error: Failed to clone System Design Primer."
        echo "Check your internet connection and try again."
        exit 1
    fi
fi

# --- Clone Server Survival ---

if [ -d "$GAME_DIR" ]; then
    echo "Server Survival already exists at $GAME_DIR — skipping."
else
    echo "Cloning Server Survival..."
    if git clone "$GAME_REPO" "$GAME_DIR"; then
        echo "Server Survival cloned successfully."
    else
        echo "Error: Failed to clone Server Survival."
        echo "Check your internet connection and try again."
        exit 1
    fi
fi

# --- Done ---

echo ""
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Open course/START-HERE.md to start the course"
echo "  2. Play Server Survival: open deps/server-survival/index.html in your browser"
echo "  3. Read the textbook: open deps/system-design-primer/README.md"
