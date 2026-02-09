#!/bin/bash
# GRUB Installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/andrewhughes101/grub/main/install.sh | bash
#   wget -qO- https://raw.githubusercontent.com/andrewhughes101/grub/main/install.sh | bash

set -e

GRUB_DIR="${GRUB_DIR:-$HOME/.grub}"
REPO="andrewhughes101/grub"

echo "Installing GRUB to $GRUB_DIR..."

# Detect download tool
if command -v curl >/dev/null 2>&1; then
  DOWNLOAD="curl -fsSL"
elif command -v wget >/dev/null 2>&1; then
  DOWNLOAD="wget -qO-"
else
  echo "Error: Neither curl nor wget found. Please install one of them."
  exit 1
fi

# Get latest version
VERSION=$($DOWNLOAD "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
[ -z "$VERSION" ] && { echo "Error: Could not fetch latest version"; exit 1; }

echo "Installing version $VERSION..."

# Download and extract
$DOWNLOAD "https://github.com/$REPO/releases/download/v${VERSION}/grub-${VERSION}.tar.gz" | tar -xz -C "$GRUB_DIR" --strip-components=1

# Make executable
chmod +x "$GRUB_DIR/bin/"*

echo "
GRUB installed successfully!

Add to your shell profile (~/.bashrc, ~/.zshrc, etc.):
  export PATH=\"\$HOME/.grub/bin:\$PATH\"

Then reload: source ~/.bashrc

Verify: grub_client --version"
