#!/bin/bash
# ped script - Create debug scripts for testing extensions

cmd_script_help() {
    printf "${BOLD}ped script${RESET} - Create debug scripts for testing extensions\n\n"
    printf "${BOLD}USAGE:${RESET}\n"
    printf "    ped script <name> <project> [options]\n\n"
    printf "${BOLD}ARGUMENTS:${RESET}\n"
    printf "    name                    Script name (without .php extension)\n"
    printf "    project                 Project to create the script for (required)\n\n"
    printf "${BOLD}OPTIONS:${RESET}\n"
    printf "    -f, --function <name>   Function to call in script (default: test1)\n"
    printf "    -h, --help              Show this help\n\n"
    printf "${BOLD}EXAMPLES:${RESET}\n"
    printf "    ped script test my_extension       # Create /debug_scripts/my_extension/test.php\n"
    printf "    ped script bench my_ext -f benchmark\n"
}

cmd_script() {
    local name=""
    local project=""
    local function_name="test1"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cmd_script_help
                return 0
                ;;
            -f|--function)
                function_name="$2"
                shift 2
                ;;
            -*)
                error "Unknown option: $1"
                return 1
                ;;
            *)
                if [[ -z "$name" ]]; then
                    name="$1"
                elif [[ -z "$project" ]]; then
                    project="$1"
                else
                    error "Unexpected argument: $1"
                    return 1
                fi
                shift
                ;;
        esac
    done
    
    if [[ -z "$name" ]]; then
        error "Script name required"
        echo "Usage: ped script <name> <project>"
        return 1
    fi
    
    if [[ -z "$project" ]]; then
        error "Project name required"
        echo "Usage: ped script <name> <project>"
        return 1
    fi
    
    # Check project exists
    if ! project_exists "$project"; then
        error "Project not found: $project"
        echo "Run 'ped list' to see available projects"
        return 1
    fi
    
    banner
    
    # Add .php extension if not present
    local script_name="$name"
    if [[ "$name" != *.php ]]; then
        script_name="${name}.php"
    fi
    
    # Create project subfolder in debug_scripts
    local project_scripts_dir="$DEBUG_SCRIPTS_DIR/$project"
    mkdir -p "$project_scripts_dir"
    
    local script_path="$project_scripts_dir/$script_name"
    
    # Create the script
    cat > "$script_path" << EOF
<?php

// Debug script: $script_name
// Project: $project
// Created: $(date)

// Call the test function
$function_name();
EOF
    
    chmod +x "$script_path"
    
    success "Created debug script: $script_path"
    
    # Associate with project in projects.json
    add_debug_script "$project" "$script_name"
    info "Associated with project: $project"
    
    echo
    info "To debug with this script:"
    echo "  ${BOLD}ped debug $project $script_name${RESET}"
    
    echo "========================================================="
}
