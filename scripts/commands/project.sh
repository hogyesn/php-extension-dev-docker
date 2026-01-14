#!/bin/bash
# ped project - Manage project registry

cmd_project_help() {
    printf "${BOLD}ped project${RESET} - Manage project registry\n\n"
    printf "${BOLD}USAGE:${RESET}\n"
    printf "    ped project <subcommand> [arguments]\n\n"
    printf "${BOLD}SUBCOMMANDS:${RESET}\n"
    printf "    add <name> <path>       Register an existing extension\n"
    printf "    remove <name>           Unregister a project\n"
    printf "    show <name>             Show project details\n"
    printf "    set <name> <key> <val>  Set project configuration\n\n"
    printf "${BOLD}OPTIONS:${RESET}\n"
    printf "    -h, --help              Show this help\n\n"
    printf "${BOLD}EXAMPLES:${RESET}\n"
    printf "    ped project add my_ext /extensions/my_ext/my_ext\n"
    printf "    ped project remove my_extension\n"
    printf "    ped project show my_extension\n"
    printf "    ped project set my_extension build_mode prod\n"
    printf "    ped project set my_extension debug_port 3334\n"
}

cmd_project() {
    local subcommand=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cmd_project_help
                return 0
                ;;
            -*)
                error "Unknown option: $1"
                return 1
                ;;
            *)
                subcommand="$1"
                shift
                break
                ;;
        esac
    done
    
    case "$subcommand" in
        add)
            project_add "$@"
            ;;
        remove|rm)
            project_remove "$@"
            ;;
        show|info)
            project_show "$@"
            ;;
        set)
            project_set "$@"
            ;;
        "")
            cmd_project_help
            ;;
        *)
            error "Unknown subcommand: $subcommand"
            echo "Run 'ped project --help' for available subcommands."
            return 1
            ;;
    esac
}

project_add() {
    local name="$1"
    local path="$2"
    local build_mode="${3:-debug}"
    local debug_port="${4:-3333}"
    
    if [[ -z "$name" ]] || [[ -z "$path" ]]; then
        error "Name and path required"
        echo "Usage: ped project add <name> <path> [build_mode] [debug_port]"
        return 1
    fi
    
    # Validate path exists
    if [[ ! -d "$path" ]]; then
        error "Path does not exist: $path"
        return 1
    fi
    
    # Check if it looks like an extension directory
    if [[ ! -f "$path/config.m4" ]] && [[ ! -f "$path/config.w32" ]]; then
        warn "Path doesn't look like a PHP extension directory (no config.m4)"
        source "$SCRIPT_DIR/lib/prompts.sh"
        if ! confirm "Register anyway?"; then
            return 0
        fi
    fi
    
    banner
    register_project "$name" "$path" "$build_mode" "$debug_port"
    echo "========================================================="
}

project_remove() {
    local name="$1"
    
    if [[ -z "$name" ]]; then
        error "Project name required"
        echo "Usage: ped project remove <name>"
        return 1
    fi
    
    banner
    unregister_project "$name"
    echo "========================================================="
}

project_show() {
    local name="$1"
    
    if [[ -z "$name" ]]; then
        error "Project name required"
        echo "Usage: ped project show <name>"
        return 1
    fi
    
    init_projects_file
    
    if ! project_exists "$name"; then
        error "Project not found: $name"
        return 1
    fi
    
    banner
    info "Project: ${BOLD}$name${RESET}"
    echo
    
    jq -r ".projects[\"$name\"] | to_entries[] | \"  \(.key): \(.value)\"" "$PROJECTS_FILE"
    
    # Show debug scripts
    local scripts
    scripts=$(jq -r ".projects[\"$name\"].debug_scripts // [] | .[]" "$PROJECTS_FILE")
    if [[ -n "$scripts" ]]; then
        echo
        echo "  debug_scripts:"
        echo "$scripts" | while read -r script; do
            echo "    - $script"
        done
    fi
    
    echo "========================================================="
}

project_set() {
    local name="$1"
    local key="$2"
    local value="$3"
    
    if [[ -z "$name" ]] || [[ -z "$key" ]] || [[ -z "$value" ]]; then
        error "Name, key, and value required"
        echo "Usage: ped project set <name> <key> <value>"
        echo "Keys: build_mode, debug_port, path"
        return 1
    fi
    
    if ! project_exists "$name"; then
        error "Project not found: $name"
        return 1
    fi
    
    banner
    
    # Determine value type
    local value_type="string"
    if [[ "$key" == "debug_port" ]]; then
        value_type="number"
    fi
    
    update_project_field "$name" "$key" "$value" "$value_type"
    success "Updated $name.$key = $value"
    echo "========================================================="
}
