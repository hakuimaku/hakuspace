#!/usr/bin/env bash
# HakuSpace Runtime Context
# Manages execution ID, shared backup directory, and runtime environment.

# Ensure HAKU_DIR is resolved
if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi
export HAKU_DIR

# Establish shared run ID and backup context across child processes
if [[ -z "${HAKUSPACE_RUN_ID:-}" ]]; then
    export HAKUSPACE_RUN_ID="$(date +%Y-%m-%d_%H-%M-%S)"
fi

if [[ -z "${BACKUP_TS:-}" ]]; then
    export BACKUP_TS="$HAKUSPACE_RUN_ID"
fi

if [[ -z "${BACKUP_DIR:-}" ]]; then
    export BACKUP_DIR="$HOME/.backup/Backup_$BACKUP_TS"
fi
export BACKUP_DIR
export BACKUP_TS
export HAKUSPACE_RUN_ID

# Deploy mode export if present
if [[ -n "${HAKUSPACE_DEPLOY_MODE:-}" ]]; then
    export HAKUSPACE_DEPLOY_MODE
fi
