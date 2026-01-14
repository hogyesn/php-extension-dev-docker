#!/bin/bash
# Interactive prompt utilities

# Prompt for input with default value
prompt() {
    local message="$1"
    local default="${2:-}"
    local result
    
    if [[ -n "$default" ]]; then
        read -rp "$message [$default]: " result
        echo "${result:-$default}"
    else
        read -rp "$message: " result
        echo "$result"
    fi
}

# Prompt for yes/no confirmation
confirm() {
    local message="$1"
    local default="${2:-y}"
    local result
    
    if [[ "$default" == "y" ]]; then
        read -rp "$message [Y/n]: " result
        [[ -z "$result" || "$result" =~ ^[Yy] ]]
    else
        read -rp "$message [y/N]: " result
        [[ "$result" =~ ^[Yy] ]]
    fi
}

# Select from options
select_option() {
    local prompt_msg="$1"
    shift
    local options=("$@")
    
    echo "$prompt_msg"
    local i=1
    for opt in "${options[@]}"; do
        echo "  $i) $opt"
        ((i++))
    done
    
    local choice
    read -rp "Enter choice [1-${#options[@]}]: " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
        echo "${options[$((choice-1))]}"
    else
        error "Invalid choice: $choice"
        return 1
    fi
}
