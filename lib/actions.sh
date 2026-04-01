#!/usr/bin/env bash

# ---- Pod Actions ----
kn_pod_logs() {
    local pod="$1"
    
    # Check containers
    local containers
    containers=$(kn_kubectl get pod "$pod" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)
    local container_count
    container_count=$(echo "$containers" | wc -w)
    
    local container_arg=""
    if [[ "$container_count" -gt 1 ]]; then
        local selected_container
        selected_container=$(echo "$containers" | tr ' ' '\n' | fzf --prompt="Select Container> " --height="30%")
        if [[ -z "$selected_container" ]]; then return; fi
        container_arg="-c ${selected_container}"
    fi

    echo -e "  [1] Tail 100 lines (default)"
    echo -e "  [2] Tail 500 lines"
    echo -e "  [3] Follow (-f)"
    echo -ne "Select action [1]: "
    read -r -n 1 log_action
    echo ""
    
    case "$log_action" in
        2) kn_kubectl logs --tail=500 "$pod" ${container_arg} | ${KN_PAGER} ;;
        3) kn_kubectl logs -f --tail=100 "$pod" ${container_arg} ;;
        *) kn_kubectl logs --tail=100 "$pod" ${container_arg} | ${KN_PAGER} ;;
    esac
}

kn_pod_exec() {
    local pod="$1"
    
    # Detect shell
    local test_shell="for s in bash sh ash; do if command -v \$s >/dev/null; then echo \$s; exit 0; fi; done; echo sh"
    local shell
    shell=$(kn_kubectl exec "$pod" -- sh -c "$test_shell" 2>/dev/null | tr -d '\r')
    if [[ -z "$shell" ]]; then
        shell="sh"
    fi
    
    echo -e "${GREEN}Entering pod ${pod} with ${shell}...${RESET}"
    kn_kubectl exec -it "$pod" -- "$shell"
}

kn_pod_describe() {
    local pod="$1"
    kn_kubectl describe pod "$pod" | ${KN_PAGER}
}

kn_pod_env() {
    local pod="$1"
    kn_kubectl exec "$pod" -- env | sort | ${KN_PAGER}
}

kn_pod_delete() {
    local pod="$1"
    if kn_confirm_dangerous "Delete Pod" "You are about to delete Pod: $pod"; then
        kn_kubectl delete pod "$pod"
        echo -e "${GREEN}Pod $pod deleted.${RESET}"
    fi
}

# ---- ConfigMap Actions ----
kn_cm_view() {
    local cm="$1"
    kn_kubectl get cm "$cm" -o yaml | ${KN_PAGER}
}

kn_cm_edit() {
    local cm="$1"
    if kn_confirm_dangerous "Edit ConfigMap" "You are about to edit ConfigMap: $cm"; then
        kn_kubectl edit cm "$cm"
    fi
}

# ---- Deployment Actions ----
kn_deploy_view() {
    local deploy="$1"
    kn_kubectl describe deploy "$deploy" | ${KN_PAGER}
}

kn_deploy_set_image() {
    local deploy="$1"
    local current_image
    current_image=$(kn_kubectl get deploy "$deploy" -o jsonpath='{.spec.template.spec.containers[0].image}')
    echo -e "Current image: ${GREEN}${current_image}${RESET}"
    echo -ne "Enter new image (leave empty to cancel): "
    read -r new_image
    
    if [[ -n "$new_image" ]]; then
        if kn_confirm_dangerous "Change Image" "Deployment $deploy image will be updated to $new_image"; then
            local container_name
            container_name=$(kn_kubectl get deploy "$deploy" -o jsonpath='{.spec.template.spec.containers[0].name}')
            kn_kubectl set image "deploy/${deploy}" "${container_name}=${new_image}"
            echo -e "${GREEN}Rollout started. Monitoring status...${RESET}"
            kn_kubectl rollout status "deploy/${deploy}"
        fi
    fi
}

kn_deploy_edit() {
    local deploy="$1"
    if kn_confirm_dangerous "Edit Deployment" "You are about to edit Deployment: $deploy"; then
        kn_kubectl edit deploy "$deploy"
    fi
}

# ---- Service Actions ----
kn_svc_view() {
    local svc="$1"
    kn_kubectl describe svc "$svc" | ${KN_PAGER}
}

kn_action_menu() {
    local res_type="$1"
    local res_name="$2"
    
    while true; do
        echo -e "\n${BLUE}━━━ ${res_type}/${res_name} ━━━${RESET}"
        
        if [[ "$res_type" == "pod" ]]; then
            echo -e "  ${BOLD}[l]${RESET} Logs    ${BOLD}[x]${RESET} Exec    ${BOLD}[d]${RESET} Describe    ${BOLD}[e]${RESET} Env    ${BOLD}[R]${RESET} Delete Pod"
        elif [[ "$res_type" == "deploy" ]]; then
            echo -e "  ${BOLD}[D]${RESET} View Deploy  ${BOLD}[i]${RESET} Change Image    ${BOLD}[E]${RESET} Edit Deploy"
        elif [[ "$res_type" == "svc" ]]; then
            echo -e "  ${BOLD}[s]${RESET} View Service"
        elif [[ "$res_type" == "cm" ]]; then
            echo -e "  ${BOLD}[c]${RESET} View ConfigMap  ${BOLD}[C]${RESET} Edit ConfigMap"
        fi
        
        echo -e "  ${BOLD}[q]${RESET} Quit"
        
        echo -ne "\nSelect action: "
        read -r -n 1 choice
        echo ""
        
        case "$choice" in
            l) if [[ "$res_type" == "pod" ]]; then kn_pod_logs "$res_name"; fi ;;
            x) if [[ "$res_type" == "pod" ]]; then kn_pod_exec "$res_name"; fi ;;
            d) if [[ "$res_type" == "pod" ]]; then kn_pod_describe "$res_name"; fi ;;
            e) if [[ "$res_type" == "pod" ]]; then kn_pod_env "$res_name"; fi ;;
            R) if [[ "$res_type" == "pod" ]]; then kn_pod_delete "$res_name"; break; fi ;;
            c) if [[ "$res_type" == "cm" ]]; then kn_cm_view "$res_name"; fi ;;
            C) if [[ "$res_type" == "cm" ]]; then kn_cm_edit "$res_name"; fi ;;
            D) if [[ "$res_type" == "deploy" ]]; then kn_deploy_view "$res_name"; fi ;;
            i) if [[ "$res_type" == "deploy" ]]; then kn_deploy_set_image "$res_name"; fi ;;
            E) if [[ "$res_type" == "deploy" ]]; then kn_deploy_edit "$res_name"; fi ;;
            s) if [[ "$res_type" == "svc" ]]; then kn_svc_view "$res_name"; fi ;;
            q|Q) break ;;
            *) echo -e "${RED}Invalid option${RESET}" ;;
        esac
    done
}

# ---- Topology ----
kn_topo_show() {
    local svc="$1"
    echo -e "${BLUE}Topology for ${svc}...${RESET}"
    kn_kubectl get svc "$svc"
    echo "---"
    kn_kubectl get endpoints "$svc"
    # Additional topology logic would go here
    read -p "Press enter to continue..."
}

# ---- Port Forward ----
kn_port_forward() {
    local pod="$1"
    echo -e "Enter local port: "
    read local_port
    echo -e "Enter remote port: "
    read remote_port
    echo -e "Starting port-forward: ${local_port}:${remote_port}"
    kn_kubectl port-forward "$pod" "${local_port}:${remote_port}"
}
