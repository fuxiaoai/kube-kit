#!/usr/bin/env bash

KN_CONFIG_DIR="${HOME}/.kk"
KN_CONFIG_FILE="${KN_CONFIG_DIR}/config.yaml"

kn_init_config() {
    if [[ ! -d "$KN_CONFIG_DIR" ]]; then
        mkdir -p "${KN_CONFIG_DIR}/backups"
    fi

    if [[ ! -f "$KN_CONFIG_FILE" ]]; then
        cat > "$KN_CONFIG_FILE" <<EOF
version: 1
defaults:
  namespace: "default"
  log_lines: 100
  editor: "\${EDITOR:-vim}"
  fzf_height: "60%"
EOF
    fi
}

kn_get_config() {
    # If yq is available, we could use it. For simplicity in pure bash without forcing yq:
    # Just a placeholder for actual YAML parsing, or we fall back to sensible defaults.
    local key="$1"
    local default_val="$2"
    
    # Very basic grep parsing for simple key-value (1 level)
    local val
    val=$(grep -A1 "^${key%%.*}:" "$KN_CONFIG_FILE" 2>/dev/null | grep -v "^${key%%.*}:" | grep "${key##*.}:" | awk -F': ' '{print $2}' | tr -d '"'\'' ')
    
    if [[ -z "$val" ]]; then
        echo "$default_val"
    else
        echo "$val"
    fi
}
