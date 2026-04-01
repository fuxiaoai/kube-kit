#!/usr/bin/env bash

KN_HISTORY_FILE="${HOME}/.kk/history.json"

kn_init_history() {
    if [[ ! -f "$KN_HISTORY_FILE" ]]; then
        echo "{}" > "$KN_HISTORY_FILE"
    fi
}

kn_save_context() {
    local cluster="$1"
    local ns="$2"
    local res_type="$3"
    local res_name="$4"
    
    # Just a simple JSON save using jq
    local temp_file="${KN_HISTORY_FILE}.tmp"
    jq --arg c "$cluster" \
       --arg n "$ns" \
       --arg t "$res_type" \
       --arg rn "$res_name" \
       '.last_context = {"cluster": $c, "namespace": $n, "resource_type": $t, "resource_name": $rn}' \
       "$KN_HISTORY_FILE" > "$temp_file" && mv "$temp_file" "$KN_HISTORY_FILE"
}

kn_load_context() {
    if [[ -f "$KN_HISTORY_FILE" ]]; then
        export KN_CLUSTER=$(jq -r '.last_context.cluster // empty' "$KN_HISTORY_FILE")
        export KN_NAMESPACE=$(jq -r '.last_context.namespace // empty' "$KN_HISTORY_FILE")
    fi
}
