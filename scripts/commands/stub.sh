#!/bin/bash
# ped stub - Update extension stub file (regenerate arginfo)

cmd_stub_help() {
    printf "${BOLD}ped stub${RESET} - Update extension stub file (regenerate arginfo)\n\n"
    printf "${BOLD}USAGE:${RESET}\n"
    printf "    ped stub [project] [stub_file]\n\n"
    printf "${BOLD}ARGUMENTS:${RESET}\n"
    printf "    project                 Project name or path (optional, auto-detects current dir)\n"
    printf "    stub_file               Stub file name (optional, auto-detects <project>.stub.php)\n\n"
    printf "${BOLD}DESCRIPTION:${RESET}\n"
    printf "    Regenerates arginfo header files from PHP stub files using gen_stub.php.\n"
    printf "    This is required after modifying function signatures in stub files.\n\n"
    printf "${BOLD}EXAMPLES:${RESET}\n"
    printf "    ped stub                          # Update stub in current directory\n"
    printf "    ped stub my_extension             # Update my_extension.stub.php\n"
    printf "    ped stub my_extension custom.stub.php\n"
    printf "    ped stub /path/to/extension\n\n"
    printf "${BOLD}WHAT IT DOES:${RESET}\n"
    printf "    1. Locates the extension directory and stub file\n"
    printf "    2. Runs: php build/gen_stub.php <stub_file>\n"
    printf "    3. Regenerates *_arginfo.h header file\n"
}

cmd_stub() {
    local project=""
    local stub_file=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cmd_stub_help
                return 0
                ;;
            -*)
                error "Unknown option: $1"
                return 1
                ;;
            *)
                if [[ -z "$project" ]]; then
                    project="$1"
                elif [[ -z "$stub_file" ]]; then
                    stub_file="$1"
                else
                    error "Too many arguments"
                    return 1
                fi
                shift
                ;;
        esac
    done
    
    # Resolve project path
    local extension_dir
    if [[ -z "$project" ]]; then
        # Try to auto-detect from current directory
        extension_dir="$(pwd)"
        if [[ ! -f "$extension_dir/config.m4" ]]; then
            error "Not in an extension directory and no project specified"
            info "Run from extension directory or specify project name"
            return 1
        fi
    else
        extension_dir=$(resolve_project "$project")
        if [[ -z "$extension_dir" ]]; then
            error "Could not resolve project: $project"
            return 1
        fi
    fi
    
    # Verify it's an extension directory
    if [[ ! -f "$extension_dir/config.m4" ]]; then
        error "Not a valid extension directory: $extension_dir"
        return 1
    fi
    
    # Auto-detect stub file if not provided
    if [[ -z "$stub_file" ]]; then
        local extension_name=$(basename "$extension_dir")
        stub_file="$extension_name.stub.php"
    fi
    
    # Verify stub file exists
    if [[ ! -f "$extension_dir/$stub_file" ]]; then
        error "Stub file not found: $extension_dir/$stub_file"
        info "Available stub files:"
        find "$extension_dir" -maxdepth 1 -name "*.stub.php" -exec basename {} \;
        return 1
    fi
    
    # Check for gen_stub.php
    if [[ ! -f "$extension_dir/build/gen_stub.php" ]]; then
        error "gen_stub.php not found at: $extension_dir/build/gen_stub.php"
        info "This extension may not support stub file generation"
        return 1
    fi
    
    banner "Updating stub file"
    info "Extension: $(basename "$extension_dir")"
    info "Stub file: $stub_file"
    info "Directory: $extension_dir"
    
    # Change to extension directory
    cd "$extension_dir" || {
        error "Failed to change directory to: $extension_dir"
        return 1
    }
    
    # Run gen_stub.php
    echo ""
    info "Running: php build/gen_stub.php $stub_file"
    echo ""
    
    if php build/gen_stub.php "$stub_file"; then
        echo ""
        success "Stub file updated successfully"
        
        # Show generated arginfo file
        local arginfo_file="${stub_file%.stub.php}_arginfo.h"
        if [[ -f "$arginfo_file" ]]; then
            info "Generated: $arginfo_file"
        fi
        
        echo ""
        info "Next steps:"
        echo "  1. Review the generated arginfo header file"
        echo "  2. Rebuild the extension: ped build $(basename "$extension_dir")"
        
        return 0
    else
        echo ""
        error "Failed to update stub file"
        info "Check the error messages above for details"
        return 1
    fi
}
