#!/usr/bin/env bash

# Disposable HakuSpace data always lives below the XDG cache namespace.
HAKUSPACE_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hakuspace"
