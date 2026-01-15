#!/bin/bash
# ped build - Build a PHP extension

cmd_build_help() {
    printf "${BOLD}ped build${RESET} - Build a PHP extension\n\n"
    printf "${BOLD}USAGE:${RESET}\n"
    printf "    ped build [project] [options]\n\n"
    printf "${BOLD}ARGUMENTS:${RESET}\n"
    printf "    project                 Project name or path (optional, auto-detects current dir)\n\n"
    printf "${BOLD}OPTIONS:${RESET}\n"
    printf "    -m, --mode <mode>       Build mode: debug (default) or prod\n"
    printf "    --save-mode             Save build mode to project config\n"
    printf "    -h, --help              Show this help\n\n"
    printf "${BOLD}EXAMPLES:${RESET}\n"
    printf "    ped build                         # Build current directory\n"
    printf "    ped build my_extension            # Build by project name\n"
    printf "    ped build my_extension --mode prod\n"
    printf "    ped build /path/to/extension\n"
}

cmd_build() {
    local project=""
    local build_mode=""
    local save_mode=0
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cmd_build_help
                return 0
                ;;
            -m|--mode)
                build_mode="$2"
                shift 2
                ;;
            --save-mode)
                save_mode=1
                shift
                ;;
            -*)
                error "Unknown option: $1"
                return 1
                ;;
            *)
                project="$1"
                shift
                ;;
        esac
    done
    
    banner
    
    # Resolve project path
    local project_path
    if ! project_path=$(resolve_project "$project"); then
        return 1
    fi
    
    # Get extension name from path
    local extension_name
    extension_name=$(basename "$project_path")
    
    # Get build mode from project config if not specified
    if [[ -z "$build_mode" ]]; then
        if [[ -n "$project" ]] && project_exists "$project"; then
            build_mode=$(get_project_build_mode "$project")
        else
            build_mode="debug"
        fi
    fi
    
    info "Building extension: ${BOLD}$extension_name${RESET}"
    info "Path: $project_path"
    info "Mode: $build_mode"
    echo
    
    # Change to extension directory
    cd "$project_path"
    
    # Run phpize
    info "Running phpize..."
    phpize
    
    # Configure
    info "Configuring..."
    ./configure --enable-debug --enable-"$extension_name" --with-php-config="$PHP_PREFIX/DEBUG/bin/php-config"
    
    # Clean previous build
    make clean 2>/dev/null || true
    
    # Build with appropriate flags
    if [[ "$build_mode" == "prod" ]]; then
        info "Building in production mode..."
        make -j"$(nproc)" CFLAGS="-O2 -DNDEBUG"
    else
        info "Building in debug mode..."
        make -j"$(nproc)" CFLAGS="-O0 -ggdb3" LDFLAGS="-ggdb3"
    fi
    
    # Install
    make install
    
    success "Extension built and installed"
    
    # Add to php.ini if not present
    echo
    info "Checking php.ini..."
    if ! grep -q "extension=$extension_name.so" "$PHP_PREFIX/DEBUG/etc/php.ini" 2>/dev/null; then
        echo "extension=$extension_name.so" >> "$PHP_PREFIX/DEBUG/etc/php.ini"
        success "Extension added to php.ini"
    else
        info "Extension already in php.ini"
    fi
    
    # Update project last_built timestamp
    if [[ -n "$project" ]] && project_exists "$project"; then
        local timestamp
        timestamp="$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)"
        update_project_field "$project" "last_built" "$timestamp"
        
        if [[ $save_mode -eq 1 ]]; then
            update_project_field "$project" "build_mode" "$build_mode"
            info "Saved build mode: $build_mode"
        fi
    fi
    
    # Verify extension loads
    echo
    info "Verifying extension..."
    if php -m 2>/dev/null | grep -q "$extension_name"; then
        success "Extension $extension_name is loaded successfully"
    else
        warn "Extension $extension_name may not be loaded correctly"
    fi
    
    # Run tests
    echo
    info "Running tests..."
    make test TESTS="-q" || true
    
    echo "========================================================="
}
