#!/usr/bin/env bash

# Disposable HakuSpace data always lives below the XDG cache namespace.
HAKU_BIN_DIR="${HAKU_BIN_DIR:-$HOME/.local/bin}"
HAKUSPACE_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hakuspace"
