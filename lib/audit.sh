#!/usr/bin/env bash

# Audit logs
KN_AUDIT_FILE="${HOME}/.kk/audit.log"

kn_audit_log() {
    local action="$1"
    local details="$2"
    local ts
    ts=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$ts] USER=${USER} CLUSTER=${KN_CLUSTER} NS=${KN_NAMESPACE} ACTION=${action} DETAILS=${details}" >> "$KN_AUDIT_FILE"
}
