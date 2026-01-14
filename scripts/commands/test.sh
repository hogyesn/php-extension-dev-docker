#!/bin/bash
# ped test - Run tests for a PHP extension

cmd_test_help() {
    printf "${BOLD}ped test${RESET} - Run tests for a PHP extension\n\n"
    printf "${BOLD}USAGE:${RESET}\n"
    printf "    ped test [project] [options]\n\n"
    printf "${BOLD}ARGUMENTS:${RESET}\n"
    printf "    project                 Project name or path (optional, auto-detects current dir)\n\n"
    printf "${BOLD}OPTIONS:${RESET}\n"
    printf "    -v, --verbose           Verbose test output\n"
    printf "    -h, --help              Show this help\n\n"
    printf "${BOLD}EXAMPLES:${RESET}\n"
    printf "    ped test                          # Test current directory\n"
    printf "    ped test my_extension             # Test by project name\n"
    printf "    ped test my_extension --verbose\n"
}

cmd_test() {
    local project=""
    local verbose=0
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cmd_test_help
                return 0
                ;;
            -v|--verbose)
                verbose=1
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
    
    # Get extension name
    local extension_name
    extension_name=$(basename "$project_path")
    
    info "Running tests for: ${BOLD}$extension_name${RESET}"
    info "Path: $project_path"
    echo
    
    # Change to extension directory
    cd "$project_path"
    
    # Check if tests directory exists
    if [[ ! -d "tests" ]]; then
        warn "No tests directory found"
        return 0
    fi
    
    # Count test files
    local test_count
    test_count=$(find tests -name "*.phpt" 2>/dev/null | wc -l)
    info "Found $test_count test file(s)"
    echo
    
    # Run tests
    if [[ $verbose -eq 1 ]]; then
        make test
    else
        make test TESTS="-q"
    fi
    
    echo "========================================================="
}
