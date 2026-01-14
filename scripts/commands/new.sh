#!/bin/bash
# ped new - Create a new PHP extension project

cmd_new_help() {
    printf "${BOLD}ped new${RESET} - Create a new PHP extension project\n\n"
    printf "${BOLD}USAGE:${RESET}\n"
    printf "    ped new [name] [options]\n\n"
    printf "${BOLD}ARGUMENTS:${RESET}\n"
    printf "    name                    Extension name (interactive if not provided)\n\n"
    printf "${BOLD}OPTIONS:${RESET}\n"
    printf "    -d, --dir <path>        Custom extension directory\n"
    printf "    -b, --build-mode <mode> Default build mode: debug (default) or prod\n"
    printf "    -p, --port <port>       Default debug port (default: 3333)\n"
    printf "    --no-register           Don't register in projects.json\n"
    printf "    -h, --help              Show this help\n\n"
    printf "${BOLD}EXAMPLES:${RESET}\n"
    printf "    ped new                           # Interactive mode\n"
    printf "    ped new my_extension              # Create with defaults\n"
    printf "    ped new my_extension --dir /custom/path\n"
    printf "    ped new my_extension --build-mode prod --port 3334\n"
}

cmd_new() {
    source "$SCRIPT_DIR/lib/prompts.sh"
    
    local name=""
    local dir=""
    local build_mode="debug"
    local debug_port=3333
    local register=1
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cmd_new_help
                return 0
                ;;
            -d|--dir)
                dir="$2"
                shift 2
                ;;
            -b|--build-mode)
                build_mode="$2"
                shift 2
                ;;
            -p|--port)
                debug_port="$2"
                shift 2
                ;;
            --no-register)
                register=0
                shift
                ;;
            -*)
                error "Unknown option: $1"
                return 1
                ;;
            *)
                name="$1"
                shift
                ;;
        esac
    done
    
    banner
    
    # Interactive mode if no name provided
    if [[ -z "$name" ]]; then
        info "Creating new PHP extension (interactive mode)"
        echo
        
        name=$(prompt "Extension name")
        if [[ -z "$name" ]]; then
            error "Extension name is required"
            return 1
        fi
        
        local default_dir="$EXTENSIONS_DIR/$name"
        dir=$(prompt "Extension directory" "$default_dir")
        
        build_mode=$(prompt "Default build mode" "debug")
        debug_port=$(prompt "Default debug port" "3333")
    else
        dir="${dir:-$EXTENSIONS_DIR/$name}"
    fi
    
    # Validate name (alphanumeric and underscores only)
    if ! [[ "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        error "Invalid extension name: $name"
        echo "Name must start with a letter/underscore and contain only alphanumerics/underscores"
        return 1
    fi
    
    # Check if project already registered
    if project_exists "$name"; then
        warn "Project '$name' already registered"
        if ! confirm "Continue and overwrite?"; then
            info "Aborted"
            return 0
        fi
    fi
    
    # Check if directory already exists
    if [[ -d "$dir/$name" ]]; then
        warn "Directory $dir/$name already exists"
        if ! confirm "Overwrite existing files?"; then
            info "Aborted"
            return 0
        fi
    fi
    
    info "Creating extension skeleton..."
    mkdir -p "$dir"
    
    # Call PHP skeleton generator
    php /usr/src/php-src/ext/ext_skel.php --ext "$name" --dir "$dir"
    
    success "Extension skeleton created at $dir/$name"
    
    # Register project
    if [[ $register -eq 1 ]]; then
        register_project "$name" "$dir/$name" "$build_mode" "$debug_port"
    fi
    
    echo
    info "Next steps:"
    echo "  1. Edit ${BOLD}$dir/$name/${name}.c${RESET} to add your extension code"
    echo "  2. Run ${BOLD}ped build $name${RESET} to build the extension"
    echo "  3. Run ${BOLD}ped test $name${RESET} to run tests"
    echo "========================================================="
}
