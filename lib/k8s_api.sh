#!/usr/bin/env bash

# Wrapper for kubectl to inject context and namespace
kn_kubectl() {
    local cmd=(kubectl)
    if [[ -n "$KN_CLUSTER" ]]; then
        cmd+=(--context="$KN_CLUSTER")
    fi
    if [[ -n "$KN_NAMESPACE" && "$KN_NAMESPACE" != "all" ]]; then
        cmd+=(--namespace="$KN_NAMESPACE")
    elif [[ "$KN_NAMESPACE" == "all" ]]; then
        cmd+=(--all-namespaces)
    fi
    "${cmd[@]}" "$@"
}

kn_cache_dir="/tmp/kk_cache"
mkdir -p "$kn_cache_dir"

kn_cache_get() {
    local key="$1"
    local ttl="$2"
    local cache_file="${kn_cache_dir}/${key}"
    
    if [[ -f "$cache_file" ]]; then
        local now
        now=$(date +%s)
        local mtime
        if [[ "$(uname -s)" == "Darwin" ]]; then
            mtime=$(stat -f %m "$cache_file")
        else
            mtime=$(stat -c %Y "$cache_file")
        fi
        
        if [[ $((now - mtime)) -lt $ttl ]]; then
            cat "$cache_file"
            return 0
        fi
    fi
    return 1
}

kn_cache_set() {
    local key="$1"
    local cache_file="${kn_cache_dir}/${key}"
    cat > "$cache_file"
}

kn_get_resources() {
    local res_type="$1"
    local no_cache="$2"
    
    local cache_key="${KN_CLUSTER}_${KN_NAMESPACE}_${res_type}.json"
    cache_key=$(echo "$cache_key" | tr -cd '[:alnum:]_.-')
    
    if [[ -z "$no_cache" ]]; then
        if kn_cache_get "$cache_key" 30; then
            return
        fi
    fi
    
    local data
    data=$(kn_kubectl get "$res_type" -o json 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        echo "$data" | kn_cache_set "$cache_key"
        echo "$data"
    fi
}

kn_get_pods() {
    kn_get_resources pods "$1"
}

kn_get_deployments() {
    kn_get_resources deployments "$1"
}

kn_get_services() {
    kn_get_resources services "$1"
}

kn_get_configmaps() {
    kn_get_resources configmaps "$1"
}

kn_get_statefulsets() {
    kn_get_resources statefulsets "$1"
}
