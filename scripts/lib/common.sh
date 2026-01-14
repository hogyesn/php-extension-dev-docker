#!/bin/bash
# Common utilities for ped commands

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1
readonly EXIT_USAGE=2

# Paths
readonly EXTENSIONS_DIR="${EXTENSIONS_DIR:-/extensions}"
readonly DEBUG_SCRIPTS_DIR="${DEBUG_SCRIPTS_DIR:-/debug_scripts}"
readonly PROJECTS_FILE="${PROJECTS_FILE:-$EXTENSIONS_DIR/projects.json}"

# Banner
banner() {
    echo "========================================================="
    echo "PHP Extension Development Environment (php ${PHP_VERSION:-unknown})"
    echo "========================================================="
}

# Logging functions
info() {
    echo -e "${BLUE}ℹ${RESET} $*"
}

success() {
    echo -e "${GREEN}✓${RESET} $*"
}

warn() {
    echo -e "${YELLOW}⚠${RESET} $*" >&2
}

error() {
    echo -e "${RED}✗${RESET} $*" >&2
}

# Validation helpers
require_arg() {
    local name="$1"
    local value="$2"
    local usage="$3"
    
    if [[ -z "$value" ]]; then
        error "Missing required argument: $name"
        echo "Usage: $usage"
        exit $EXIT_USAGE
    fi
}

require_dir() {
    local path="$1"
    local name="${2:-Directory}"
    
    if [[ ! -d "$path" ]]; then
        error "$name does not exist: $path"
        exit $EXIT_ERROR
    fi
}

require_file() {
    local path="$1"
    local name="${2:-File}"
    
    if [[ ! -f "$path" ]]; then
        error "$name does not exist: $path"
        exit $EXIT_ERROR
    fi
}

# Check if running in Docker container
is_in_container() {
    [[ -f /.dockerenv ]]
}
