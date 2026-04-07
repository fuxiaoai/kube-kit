#!/usr/bin/env bash

# ANSI colors
export GREEN='\033[32m'
export RED='\033[31m'
export YELLOW='\033[33m'
export BLUE='\033[34m'
export GRAY='\033[90m'
export BOLD='\033[1m'
export RESET='\033[0m'

export KN_RC_BACK=101
export KN_RC_NO_RESOURCES=102
export KN_RC_EXIT=130
export KN_FZF_LAST_KEY=""

kn_log_info() {
    echo -e "${BLUE}[INFO]${RESET} $1" >&2
}

kn_log_success() {
    echo -e "${GREEN}[SUCCESS]${RESET} $1" >&2
}

kn_log_warn() {
    echo -e "${YELLOW}[WARN]${RESET} $1" >&2
}

kn_log_error() {
    echo -e "${RED}[ERROR]${RESET} $1" >&2
}

kn_die() {
    kn_log_error "$1"
    exit 1
}

kn_check_dependencies() {
    local missing=0
    for cmd in kubectl fzf jq; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            kn_log_error "Missing required dependency: $cmd"
            missing=1
        fi
    done
    if [[ "$missing" -eq 1 ]]; then
        kn_die "Please install missing dependencies and try again."
    fi
    
    # Optional dependencies
    if command -v bat >/dev/null 2>&1; then
        export KN_PAGER="bat --style=plain --paging=never"
    else
        export KN_PAGER="cat"
    fi
}

kn_confirm_dangerous() {
    local action="$1" detail="$2"
    echo -e "${YELLOW}⚠ WARNING: ${action}${RESET}"
    echo -e "${detail}"
    echo -ne "Type ${BOLD}'yes'${RESET} to confirm: "
    local answer
    read -r answer
    [[ "$answer" == "yes" ]]
}
