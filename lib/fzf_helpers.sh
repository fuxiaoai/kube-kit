#!/usr/bin/env bash

# For fzf preview functions to be exported, we need to declare them and export them
# so fzf can invoke them in a subshell.

export KN_BIN="${KN_BIN:-$0}"

kn_fzf_preview_pod() {
    local pod_name="$1"
    local ns="$2"
    local ctx="$3"
    
    echo -e "\033[90m$ kubectl --context=$ctx -n $ns describe pod $pod_name\033[0m"
    echo -e "\033[34m━━━ Pod: $pod_name ━━━\033[0m\n"
    
    # Very quick preview using kubectl
    kubectl --context="$ctx" -n "$ns" get pod "$pod_name" -o wide
    echo -e "\n\033[33mRecent Logs:\033[0m"
    kubectl --context="$ctx" -n "$ns" logs --tail=5 "$pod_name" 2>/dev/null || echo "No logs available"
    echo -e "\n\033[33mRecent Events:\033[0m"
    kubectl --context="$ctx" -n "$ns" get events --field-selector involvedObject.name="$pod_name" --sort-by='.lastTimestamp' | tail -n 5
}
export -f kn_fzf_preview_pod

kn_fzf_preview_deploy() {
    local name="$1"
    local ns="$2"
    local ctx="$3"

    echo -e "\033[90m$ kubectl --context=$ctx -n $ns describe deploy $name\033[0m"
    echo -e "\033[34m━━━ Deployment: $name ━━━\033[0m\n"
    kubectl --context="$ctx" -n "$ns" get deploy "$name" -o wide
    echo ""
    kubectl --context="$ctx" -n "$ns" describe deploy "$name" | grep -A 5 -E "^Replicas|^Pod Template"
}
export -f kn_fzf_preview_deploy

kn_fzf_preview_svc() {
    local name="$1"
    local ns="$2"
    local ctx="$3"

    echo -e "\033[90m$ kubectl --context=$ctx -n $ns describe svc $name\033[0m"
    echo -e "\033[34m━━━ Service: $name ━━━\033[0m\n"
    kubectl --context="$ctx" -n "$ns" get svc "$name" -o wide
    echo ""
    kubectl --context="$ctx" -n "$ns" describe svc "$name" | grep -E "^Type:|^IP:|^Port:|^TargetPort:|^Endpoints:"
}
export -f kn_fzf_preview_svc

kn_fzf_preview_cm() {
    local name="$1"
    local ns="$2"
    local ctx="$3"

    echo -e "\033[90m$ kubectl --context=$ctx -n $ns get cm $name -o yaml\033[0m"
    echo -e "\033[34m━━━ ConfigMap: $name ━━━\033[0m\n"
    kubectl --context="$ctx" -n "$ns" get cm "$name" -o yaml | head -n 30
}
export -f kn_fzf_preview_cm

kn_fzf_select() {
    local header="$1"
    local preview_cmd="$2"
    local multi="$3"
    local query="$4"
    local prompt="$5"
    local height="${6:-60%}"
    local output
    local status
    
    KN_FZF_LAST_KEY=""

    local fzf_opts=(
        --ansi
        --header="$header"
        --height="$height"
        --bind="ctrl-/:toggle-preview"
        --bind="ctrl-y:execute(echo {} | pbcopy 2>/dev/null || echo {} | xclip -sel clip 2>/dev/null || echo {} | clip.exe 2>/dev/null)+abort"
        --expect="esc"
    )

    if [[ -n "$prompt" ]]; then
        fzf_opts+=(--prompt="$prompt")
    fi

    if [[ -n "$query" ]]; then
        fzf_opts+=(--query="$query")
    fi
    
    if [[ -n "$preview_cmd" ]]; then
        fzf_opts+=(--preview="$preview_cmd" --preview-window="right:50%:wrap")
    fi
    
    if [[ "$multi" == "multi" ]]; then
        fzf_opts+=(--multi)
    fi
    
    output=$(fzf "${fzf_opts[@]}")
    status=$?

    if [[ "$status" -ne 0 ]]; then
        return "$status"
    fi

    if [[ "$output" == *$'\n'* ]]; then
        KN_FZF_LAST_KEY="${output%%$'\n'*}"
        output="${output#*$'\n'}"
    elif [[ "$output" == "esc" ]]; then
        KN_FZF_LAST_KEY="esc"
        output=""
    fi

    if [[ "$KN_FZF_LAST_KEY" == "esc" ]]; then
        return "$KN_RC_BACK"
    fi

    printf '%s\n' "$output"
}
