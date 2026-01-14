#!/bin/bash
# ped list - List registered projects and discover extensions

cmd_list_help() {
    printf "${BOLD}ped list${RESET} - List registered projects and discover extensions\n\n"
    printf "${BOLD}USAGE:${RESET}\n"
    printf "    ped list [options]\n\n"
    printf "${BOLD}OPTIONS:${RESET}\n"
    printf "    -a, --all               Show all details including debug scripts\n"
    printf "    -h, --help              Show this help\n\n"
    printf "${BOLD}EXAMPLES:${RESET}\n"
    printf "    ped list\n"
    printf "    ped list --all\n"
}

# Discover debug scripts for a project
discover_debug_scripts() {
    local project_name="$1"
    local scripts_dir="$DEBUG_SCRIPTS_DIR/$project_name"
    
    if [[ -d "$scripts_dir" ]]; then
        find "$scripts_dir" -name "*.php" -type f 2>/dev/null | while read -r script; do
            local script_name
            script_name=$(basename "$script")
            # Add to project if not already there
            add_debug_script "$project_name" "$script_name"
        done
    fi
}

cmd_list() {
    local show_all=0
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cmd_list_help
                return 0
                ;;
            -a|--all)
                show_all=1
                shift
                ;;
            -*)
                error "Unknown option: $1"
                return 1
                ;;
            *)
                error "Unexpected argument: $1"
                return 1
                ;;
        esac
    done
    
    banner
    
    init_projects_file
    
    # Get registered project names
    local registered_names
    registered_names=$(get_project_names)
    
    # Discover and auto-register extensions first
    info "Discovering extensions in $EXTENSIONS_DIR..."
    
    local found_new=0
    
    # Find directories with config.m4 (PHP extension indicator)
    while IFS= read -r -d '' config_file; do
        local ext_dir
        ext_dir=$(dirname "$config_file")
        local ext_name
        ext_name=$(basename "$ext_dir")
        
        # Check if this extension is already registered (by path)
        local is_registered=0
        while IFS= read -r registered_name; do
            if [[ -n "$registered_name" ]]; then
                local registered_path
                registered_path=$(get_project_path "$registered_name")
                if [[ "$registered_path" == "$ext_dir" ]]; then
                    is_registered=1
                    break
                fi
            fi
        done <<< "$registered_names"
        
        if [[ $is_registered -eq 0 ]]; then
            # Auto-register the extension
            register_project "$ext_name" "$ext_dir" "debug" 3333
            found_new=1
        fi
    done < <(find "$EXTENSIONS_DIR" -name "config.m4" -print0 2>/dev/null)
    
    if [[ $found_new -eq 0 ]]; then
        info "No new extensions found"
    fi
    
    # Discover debug scripts for all projects
    info "Discovering debug scripts..."
    while IFS= read -r project_name; do
        if [[ -n "$project_name" ]]; then
            discover_debug_scripts "$project_name"
        fi
    done <<< "$(get_project_names)"
    
    echo
    
    # Count projects (after discovery)
    local count
    count=$(jq '.projects | length' "$PROJECTS_FILE")
    
    # Show all registered projects
    if [[ "$count" -gt 0 ]]; then
        info "Registered projects ($count):"
        echo
        
        if [[ $show_all -eq 1 ]]; then
            # Detailed output with debug scripts
            while IFS= read -r project_name; do
                if [[ -n "$project_name" ]]; then
                    echo "  ${BOLD}$project_name${RESET}:"
                    local path mode port created last_built
                    path=$(jq -r ".projects[\"$project_name\"].path" "$PROJECTS_FILE")
                    mode=$(jq -r ".projects[\"$project_name\"].build_mode" "$PROJECTS_FILE")
                    port=$(jq -r ".projects[\"$project_name\"].debug_port" "$PROJECTS_FILE")
                    created=$(jq -r ".projects[\"$project_name\"].created_at // \"unknown\"" "$PROJECTS_FILE")
                    last_built=$(jq -r ".projects[\"$project_name\"].last_built // \"never\"" "$PROJECTS_FILE")
                    
                    echo "    Path: $path"
                    echo "    Build mode: $mode"
                    echo "    Debug port: $port"
                    echo "    Created: $created"
                    echo "    Last built: $last_built"
                    
                    # Show debug scripts
                    local scripts
                    scripts=$(jq -r ".projects[\"$project_name\"].debug_scripts // [] | .[]" "$PROJECTS_FILE" 2>/dev/null)
                    if [[ -n "$scripts" ]]; then
                        echo "    Debug scripts:"
                        echo "$scripts" | while read -r script; do
                            echo "      - $script"
                        done
                    fi
                    echo
                fi
            done <<< "$(get_project_names)"
        else
            # Simple table output
            printf "  ${BOLD}%-20s %-40s %-8s${RESET}\n" "NAME" "PATH" "MODE"
            printf "  %-20s %-40s %-8s\n" "----" "----" "----"
            jq -r '.projects | to_entries[] | "\(.key)\t\(.value.path)\t\(.value.build_mode)"' "$PROJECTS_FILE" | while IFS=$'\t' read -r name path mode; do
                printf "  %-20s %-40s %-8s\n" "$name" "$path" "$mode"
            done
        fi
    else
        info "No projects found"
        echo
        echo "Create a new project with: ${BOLD}ped new <name>${RESET}"
    fi
    
    echo "========================================================="
}
