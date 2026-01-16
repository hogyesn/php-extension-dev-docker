#!/bin/bash
# ped debug - Debug a PHP extension with gdbserver

cmd_debug_help() {
    printf "${BOLD}ped debug${RESET} - Debug a PHP extension with gdbserver\n\n"
    printf "${BOLD}USAGE:${RESET}\n"
    printf "    ped debug <project> [script] [options]\n\n"
    printf "${BOLD}ARGUMENTS:${RESET}\n"
    printf "    project                 Project name or path\n"
    printf "    script                  PHP script (optional - interactive selection if omitted)\n\n"
    printf "${BOLD}OPTIONS:${RESET}\n"
    printf "    -p, --port <port>       GDB server port (default: 3333 or from project config)\n"
    printf "    --save-port             Save port to project config\n"
    printf "    -h, --help              Show this help\n\n"
    printf "${BOLD}EXAMPLES:${RESET}\n"
    printf "    ped debug my_extension            # Interactive script selection\n"
    printf "    ped debug my_extension test.php   # Direct script specification\n"
    printf "    ped debug my_extension --port 3334\n"
}

# Interactive script selection with last-choice memory
select_debug_script() {
    local project="$1"
    local scripts_dir="$DEBUG_SCRIPTS_DIR/$project"
    local scripts=()
    local last_script=""
    
    # Get last used script from project config
    if project_exists "$project"; then
        last_script=$(jq -r ".projects[\"$project\"].last_debug_script // empty" "$PROJECTS_FILE")
    fi
    
    # Collect scripts from project subfolder
    if [[ -d "$scripts_dir" ]]; then
        while IFS= read -r -d '' file; do
            scripts+=("$(basename "$file")")
        done < <(find "$scripts_dir" -maxdepth 1 -name "*.php" -type f -print0 2>/dev/null)
    fi
    
    # Also check root debug_scripts for backwards compatibility
    while IFS= read -r -d '' file; do
        local name
        name=$(basename "$file")
        # Only add if not already in list
        local exists=0
        for s in "${scripts[@]}"; do
            if [[ "$s" == "$name" ]]; then
                exists=1
                break
            fi
        done
        if [[ $exists -eq 0 ]]; then
            scripts+=("$name")
        fi
    done < <(find "$DEBUG_SCRIPTS_DIR" -maxdepth 1 -name "*.php" -type f -print0 2>/dev/null)
    
    if [[ ${#scripts[@]} -eq 0 ]]; then
        error "No debug scripts found for project: $project"
        echo "Create one with: ped new-script <name> $project"
        return 1
    fi
    
    # Sort scripts
    IFS=$'\n' scripts=($(sort <<<"${scripts[*]}")); unset IFS
    
    # Find index of last script
    local default_idx=1
    if [[ -n "$last_script" ]]; then
        for i in "${!scripts[@]}"; do
            if [[ "${scripts[$i]}" == "$last_script" ]]; then
                default_idx=$((i + 1))
                break
            fi
        done
    fi
    
    echo >&2
    info "Select debug script (Enter for last used):" >&2
    echo >&2
    
    local i=1
    for s in "${scripts[@]}"; do
        if [[ "$s" == "$last_script" ]]; then
            echo -e "  ${GREEN}$i) $s ${BOLD}(last used)${RESET}" >&2
        else
            echo "  $i) $s" >&2
        fi
        ((i++))
    done
    
    echo >&2
    local choice
    read -rp "Enter choice [$default_idx]: " choice
    
    # Default to last used
    if [[ -z "$choice" ]]; then
        choice=$default_idx
    fi
    
    # Validate choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#scripts[@]} )); then
        echo "${scripts[$((choice-1))]}"
    else
        error "Invalid choice: $choice"
        return 1
    fi
}

cmd_debug() {
    local project=""
    local script=""
    local port=""
    local save_port=0
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cmd_debug_help
                return 0
                ;;
            -p|--port)
                port="$2"
                shift 2
                ;;
            --port=*)
                port="${1#*=}"
                shift
                ;;
            --save-port)
                save_port=1
                shift
                ;;
            -*)
                error "Unknown option: $1"
                return 1
                ;;
            *)
                if [[ -z "$project" ]]; then
                    project="$1"
                elif [[ -z "$script" ]]; then
                    script="$1"
                else
                    error "Unexpected argument: $1"
                    return 1
                fi
                shift
                ;;
        esac
    done
    
    banner
    
    # Validate required arguments
    if [[ -z "$project" ]]; then
        error "Project name required"
        echo "Usage: ped debug <project> [script] [--port=PORT]"
        return 1
    fi
    
    # Resolve project path
    local project_path
    if ! project_path=$(resolve_project "$project"); then
        return 1
    fi
    
    # Get extension name
    local extension_name
    extension_name=$(basename "$project_path")
    
    # Get port from project config if not specified
    if [[ -z "$port" ]]; then
        if project_exists "$project"; then
            port=$(get_project_debug_port "$project")
        else
            port=3333
        fi
    fi
    
    # If no script specified, prefer interactive selection when TTY available
    if [[ -z "$script" ]]; then
        if [[ -t 0 ]]; then
            script=$(select_debug_script "$project") || return 1
        else
            # Non-interactive: try to use last_debug_script from project config
            if project_exists "$project"; then
                script=$(jq -r ".projects[\"$project\"].last_debug_script // empty" "$PROJECTS_FILE")
            fi
            if [[ -z "$script" ]]; then
                error "No script specified and no TTY for interactive selection."
                echo "Run with an interactive terminal: docker exec -it php-extension-dev ped debug $project"
                return 1
            fi
        fi
    fi
    
    # Add .php extension if not present
    if [[ "$script" != *.php ]]; then
        script="${script}.php"
    fi
    
    # Check if script exists
	local script_path="$DEBUG_SCRIPTS_DIR/$project/$script"

	if [[ ! -f "$script_path" ]]; then
		# Fallback to root debug_scripts for backwards compatibility
		script_path="$DEBUG_SCRIPTS_DIR/$script"
	fi

    if [[ ! -f "$script_path" ]]; then
        error "Debug script not found: $script_path"
        echo "Create a debug script with: ped new-script <name> $project"
        return 1
    fi
    
    # Save last used script to project config
    if project_exists "$project"; then
        update_project_field "$project" "last_debug_script" "$script"
    fi
    
    # Check if extension module exists
    local module_path="$project_path/modules/$extension_name.so"
    if [[ ! -f "$module_path" ]]; then
        error "Extension module not found: $module_path"
        echo "Build the extension first with: ped build $project"
        return 1
    fi
    
    info "Starting debug session"
    info "Extension: ${BOLD}$extension_name${RESET}"
    info "Script: $script_path"
    info "Port: $port"
    echo
    
    # Save port if requested
    if [[ $save_port -eq 1 ]] && project_exists "$project"; then
        update_project_field "$project" "debug_port" "$port" "number"
        info "Saved debug port: $port"
    fi
    
    echo -e "Connect your debugger to: ${BOLD}localhost:$port${RESET}"
    echo "========================================================="
    echo
    
    # Build the command
    local php_cmd="$PHP_PREFIX/DEBUG/bin/php"
    local extension_flag="-d extension=$module_path"
    local config_flag="-d $extension_name.enabled=1"
    
    echo "Command: gdbserver :$port $php_cmd -n $extension_flag $config_flag $script_path"
    echo
    
    # Start gdbserver
    gdbserver ":$port" "$php_cmd" -d "extension=$module_path" -d "$extension_name.enabled=1" "$script_path"
}
