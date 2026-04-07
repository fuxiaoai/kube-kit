#!/usr/bin/env bash

kn_select_cluster() {
    local contexts
    contexts=$(kubectl config get-contexts -o name)
    
    if [[ -z "$contexts" ]]; then
        kn_die "No kubeconfig contexts found."
    fi
    
    # If there's only one context, auto-select it
    if [[ $(echo "$contexts" | wc -l) -eq 1 ]]; then
        export KN_CLUSTER="$contexts"
        return
    fi
    
    local current_ctx
    current_ctx=$(kubectl config current-context 2>/dev/null)
    
    # Put current context at the top
    local sorted_ctx
    sorted_ctx=$(echo "$contexts" | grep -v "^${current_ctx}$" || true)
    if [[ -n "$current_ctx" ]]; then
        sorted_ctx="${current_ctx} (current)
${sorted_ctx}"
    fi
    
    local selected
    selected=$(echo "$sorted_ctx" | kn_fzf_select "Select Cluster (Esc stays on this level | Ctrl-C exits)" "" "" "" "Cluster> " "40%")
    local select_status=$?
    
    if [[ "$select_status" -eq "$KN_RC_BACK" ]]; then
        return "$KN_RC_BACK"
    fi

    if [[ "$select_status" -ne 0 ]]; then
        return "$select_status"
    fi

    if [[ -z "$selected" ]]; then
        return "$KN_RC_BACK"
    fi
    
    # Remove " (current)" if selected
    export KN_CLUSTER="${selected% (current)}"
}

kn_select_namespace() {
    local ns_list
    ns_list=$(kn_kubectl get ns -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n')
    
    # Put default at the top
    local sorted_ns
    sorted_ns=$(echo "$ns_list" | grep -v "^default$" || true)
    sorted_ns="default
${sorted_ns}"
    
    local selected
    selected=$(echo "$sorted_ns" | kn_fzf_select "Select Namespace (Esc goes back | Ctrl-C exits)" "" "" "" "Namespace [${KN_CLUSTER}]> " "40%")
    local select_status=$?
    
    if [[ "$select_status" -eq "$KN_RC_BACK" ]]; then
        return "$KN_RC_BACK"
    fi

    if [[ "$select_status" -ne 0 ]]; then
        return "$select_status"
    fi

    if [[ -z "$selected" ]]; then
        return "$KN_RC_BACK"
    fi
    
    export KN_NAMESPACE="$selected"
}

kn_select_resource() {
    local keyword="$1"

    # Combine pods, deployments, services, configmaps
    # First show pods
    local pod_data
    # calculate age using bash + jq
    pod_data=$(kn_get_pods | jq -r '.items[]? | 
        # Calculate age
        ( .metadata.creationTimestamp | fromdateiso8601 | (now - .) ) as $age_seconds |
        (
            if $age_seconds < 60 then "\($age_seconds|floor)s"
            elif $age_seconds < 3600 then "\($age_seconds/60|floor)m"
            elif $age_seconds < 86400 then "\($age_seconds/3600|floor)h"
            else "\($age_seconds/86400|floor)d"
            end
        ) as $age |
        # Colorize phase based on status.phase AND container statuses (like ErrImagePull, CrashLoopBackOff)
        (
            if .status.phase == "Running" or .status.phase == "Succeeded" then 
                if (.status.containerStatuses != null) then
                    # check if any container is failing despite phase being Running (e.g. CrashLoopBackOff)
                    if (.status.containerStatuses | map(select(.state.waiting != null and .state.waiting.reason != "Completed")) | length > 0) then
                        "\u001b[31m\(.status.containerStatuses | map(select(.state.waiting != null and .state.waiting.reason != "Completed")) | .[0].state.waiting.reason)\u001b[0m"
                    else
                        "\u001b[32m\(.status.phase)\u001b[0m"
                    end
                else
                    "\u001b[32m\(.status.phase)\u001b[0m"
                end
            elif .status.phase == "Pending" then
                if (.status.containerStatuses != null) then
                    # check for ErrImagePull or ImagePullBackOff (ignore ContainerCreating)
                    if (.status.containerStatuses | map(select(.state.waiting != null and .state.waiting.reason != "ContainerCreating")) | length > 0) then
                        "\u001b[31m\(.status.containerStatuses | map(select(.state.waiting != null and .state.waiting.reason != "ContainerCreating")) | .[0].state.waiting.reason // "Pending")\u001b[0m"
                    else
                        "\u001b[33m\(.status.phase)\u001b[0m"
                    end
                else
                    "\u001b[33m\(.status.phase)\u001b[0m"
                end
            elif .status.phase == "Failed" or .status.phase == "Unknown" or .status.phase == "CrashLoopBackOff" then "\u001b[31m\(.status.phase)\u001b[0m"
            else "\u001b[33m\(.status.phase)\u001b[0m"
            end
        ) as $phase |
        ["pod", .metadata.name, $phase, $age] | @tsv' 2>/dev/null || true)
    
    local deploy_data
    deploy_data=$(kn_get_deployments | jq -r '.items[]? | 
        ( .metadata.creationTimestamp | fromdateiso8601 | (now - .) ) as $age_seconds |
        (
            if $age_seconds < 60 then "\($age_seconds|floor)s"
            elif $age_seconds < 3600 then "\($age_seconds/60|floor)m"
            elif $age_seconds < 86400 then "\($age_seconds/3600|floor)h"
            else "\($age_seconds/86400|floor)d"
            end
        ) as $age |
        ["deploy", .metadata.name, (.status.readyReplicas|tostring)+"/"+(.status.replicas|tostring), $age] | @tsv' 2>/dev/null || true)
    
    local svc_data
    svc_data=$(kn_get_services | jq -r '.items[]? | 
        ( .metadata.creationTimestamp | fromdateiso8601 | (now - .) ) as $age_seconds |
        (
            if $age_seconds < 60 then "\($age_seconds|floor)s"
            elif $age_seconds < 3600 then "\($age_seconds/60|floor)m"
            elif $age_seconds < 86400 then "\($age_seconds/3600|floor)h"
            else "\($age_seconds/86400|floor)d"
            end
        ) as $age |
        ["svc", .metadata.name, .spec.type, $age] | @tsv' 2>/dev/null || true)
    
    local cm_data
    cm_data=$(kn_get_configmaps | jq -r '.items[]? | 
        ( .metadata.creationTimestamp | fromdateiso8601 | (now - .) ) as $age_seconds |
        (
            if $age_seconds < 60 then "\($age_seconds|floor)s"
            elif $age_seconds < 3600 then "\($age_seconds/60|floor)m"
            elif $age_seconds < 86400 then "\($age_seconds/3600|floor)h"
            else "\($age_seconds/86400|floor)d"
            end
        ) as $age |
        ["cm", .metadata.name, (.data | length | tostring)+" keys", $age] | @tsv' 2>/dev/null || true)
    
    local all_data="${pod_data}
${deploy_data}
${svc_data}
${cm_data}"
    
    all_data=$(echo "$all_data" | grep -v "^$" | column -t -s $'\t')
    
    if [[ -z "$all_data" ]]; then
        kn_log_warn "No resources found in namespace ${KN_NAMESPACE}"
        return "$KN_RC_NO_RESOURCES"
    fi
    
    local preview_cmd="
    if [[ {1} == 'pod' ]]; then
        bash -c \"source ${KN_BIN}; kn_fzf_preview_pod '{2}' '${KN_NAMESPACE}' '${KN_CLUSTER}'\"
    elif [[ {1} == 'deploy' ]]; then
        bash -c \"source ${KN_BIN}; kn_fzf_preview_deploy '{2}' '${KN_NAMESPACE}' '${KN_CLUSTER}'\"
    elif [[ {1} == 'svc' ]]; then
        bash -c \"source ${KN_BIN}; kn_fzf_preview_svc '{2}' '${KN_NAMESPACE}' '${KN_CLUSTER}'\"
    elif [[ {1} == 'cm' ]]; then
        bash -c \"source ${KN_BIN}; kn_fzf_preview_cm '{2}' '${KN_NAMESPACE}' '${KN_CLUSTER}'\"
    fi
    "
    
    local selected
    selected=$(echo "$all_data" | kn_fzf_select "Select Resource in ${KN_NAMESPACE} (Esc back | Ctrl-/ preview | Ctrl-y copy row | Ctrl-C exit)" "$preview_cmd" "" "$keyword")
    local select_status=$?
    
    if [[ "$select_status" -eq "$KN_RC_BACK" ]]; then
        return "$KN_RC_BACK"
    fi

    if [[ "$select_status" -ne 0 ]]; then
        return "$select_status"
    fi

    if [[ -z "$selected" ]]; then
        return "$KN_RC_BACK"
    fi
    
    export KN_RESOURCE_TYPE=$(echo "$selected" | awk '{print $1}')
    export KN_RESOURCE_NAME=$(echo "$selected" | awk '{print $2}')
    return 0
}
