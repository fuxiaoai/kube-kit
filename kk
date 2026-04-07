#!/usr/bin/env bash

# Kube-Kit (kk) - Kubernetes 一键快速导航与操作脚本

# Resolve real path of script to locate lib correctly
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

export KN_BIN="$DIR/kk"
LIB_DIR="$DIR/lib"

source "${LIB_DIR}/core.sh"
source "${LIB_DIR}/config_manager.sh"
source "${LIB_DIR}/k8s_api.sh"
source "${LIB_DIR}/fzf_helpers.sh"
source "${LIB_DIR}/navigator.sh"
source "${LIB_DIR}/actions.sh"
source "${LIB_DIR}/history.sh"

kn_main() {
    kn_check_dependencies
    kn_init_config
    kn_init_history
    
    local keyword=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -r|--repeat)
                kn_load_context
                shift
                ;;
            -c|--cluster)
                export KN_CLUSTER="$2"
                shift 2
                ;;
            -n|--namespace)
                export KN_NAMESPACE="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: kk [-c cluster] [-n namespace] [keyword]"
                exit 0
                ;;
            *)
                if [[ -z "$keyword" ]]; then
                    keyword="$1"
                fi
                shift
                ;;
        esac
    done
    
    while true; do
        # We need to explicitly handle STDIN in case of terminal disruption from kubectl
        # to ensure read commands inside and outside loop have a functional terminal
        if ! exec < /dev/tty; then
            kn_die "kk requires an interactive terminal."
        fi

        if [[ -z "$KN_CLUSTER" ]]; then
            kn_select_cluster
            local cluster_status=$?

            case "$cluster_status" in
                0) ;;
                "$KN_RC_BACK") continue ;;
                "$KN_RC_EXIT") exit "$cluster_status" ;;
                *) exit "$cluster_status" ;;
            esac
        fi

        if [[ -z "$KN_NAMESPACE" ]]; then
            kn_select_namespace
            local namespace_status=$?

            case "$namespace_status" in
                0) ;;
                "$KN_RC_BACK")
                    export KN_CLUSTER=""
                    export KN_NAMESPACE=""
                    export KN_RESOURCE_NAME=""
                    export KN_RESOURCE_TYPE=""
                    keyword=""
                    continue
                    ;;
                "$KN_RC_EXIT") exit "$namespace_status" ;;
                *) exit "$namespace_status" ;;
            esac
        fi

        if [[ -z "$KN_RESOURCE_NAME" ]]; then
            kn_select_resource "$keyword"
            local resource_status=$?

            case "$resource_status" in
                0) ;;
                "$KN_RC_BACK")
                    export KN_NAMESPACE=""
                    export KN_RESOURCE_NAME=""
                    export KN_RESOURCE_TYPE=""
                    keyword=""
                    continue
                    ;;
                "$KN_RC_NO_RESOURCES")
                    export KN_NAMESPACE=""
                    export KN_RESOURCE_NAME=""
                    export KN_RESOURCE_TYPE=""
                    keyword=""
                    continue
                    ;;
                "$KN_RC_EXIT") exit "$resource_status" ;;
                *) exit "$resource_status" ;;
            esac
        fi

        # When coming back from action menu or initially, if it's empty, we should not proceed to action menu.
        if [[ -z "$KN_RESOURCE_NAME" ]]; then
            continue
        fi

        kn_save_context "$KN_CLUSTER" "$KN_NAMESPACE" "$KN_RESOURCE_TYPE" "$KN_RESOURCE_NAME"

        kn_action_menu "$KN_RESOURCE_TYPE" "$KN_RESOURCE_NAME"
        local action_status=$?

        case "$action_status" in
            "$KN_RC_EXIT") exit "$action_status" ;;
        esac

        # After returning from action menu, clear resource name and keyword to return to resource selection
        export KN_RESOURCE_NAME=""
        export KN_RESOURCE_TYPE=""
        keyword=""
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    kn_main "$@"
fi
