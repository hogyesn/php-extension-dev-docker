#!/bin/bash
# Projects.json management utilities

# Initialize projects.json if it doesn't exist
init_projects_file() {
    if [[ ! -f "$PROJECTS_FILE" ]]; then
        echo '{"version":"1.0","projects":{}}' | jq '.' > "$PROJECTS_FILE"
    fi
}

# Get project data by name (returns JSON object or empty)
get_project() {
    local name="$1"
    init_projects_file
    jq -r ".projects[\"$name\"] // empty" "$PROJECTS_FILE"
}

# Get project path by name
get_project_path() {
    local name="$1"
    init_projects_file
    jq -r ".projects[\"$name\"].path // empty" "$PROJECTS_FILE"
}

# Get project build mode by name
get_project_build_mode() {
    local name="$1"
    init_projects_file
    jq -r ".projects[\"$name\"].build_mode // \"debug\"" "$PROJECTS_FILE"
}

# Get project debug port by name
get_project_debug_port() {
    local name="$1"
    init_projects_file
    jq -r ".projects[\"$name\"].debug_port // 3333" "$PROJECTS_FILE"
}

# Check if project exists
project_exists() {
    local name="$1"
    init_projects_file
    [[ $(jq -r ".projects | has(\"$name\")" "$PROJECTS_FILE") == "true" ]]
}

# Register a new project
register_project() {
    local name="$1"
    local path="$2"
    local build_mode="${3:-debug}"
    local debug_port="${4:-3333}"
    local created_at
    created_at="$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)"
    
    init_projects_file
    
    local tmp
    tmp=$(mktemp)
    jq --arg name "$name" \
       --arg path "$path" \
       --arg build_mode "$build_mode" \
       --argjson debug_port "$debug_port" \
       --arg created "$created_at" \
       '.projects[$name] = {
           "path": $path,
           "build_mode": $build_mode,
           "debug_port": $debug_port,
           "created_at": $created,
           "last_built": null,
           "debug_scripts": []
       }' "$PROJECTS_FILE" > "$tmp" && mv "$tmp" "$PROJECTS_FILE"
    
    success "Registered project: $name"
}

# Update project field
update_project_field() {
    local name="$1"
    local field="$2"
    local value="$3"
    local value_type="${4:-string}"  # string, number, or raw
    
    init_projects_file
    
    local tmp
    tmp=$(mktemp)
    
    case "$value_type" in
        number)
            jq --arg name "$name" \
               --arg field "$field" \
               --argjson value "$value" \
               '.projects[$name][$field] = $value' "$PROJECTS_FILE" > "$tmp"
            ;;
        raw)
            jq --arg name "$name" \
               --arg field "$field" \
               --argjson value "$value" \
               '.projects[$name][$field] = $value' "$PROJECTS_FILE" > "$tmp"
            ;;
        *)
            jq --arg name "$name" \
               --arg field "$field" \
               --arg value "$value" \
               '.projects[$name][$field] = $value' "$PROJECTS_FILE" > "$tmp"
            ;;
    esac
    
    mv "$tmp" "$PROJECTS_FILE"
}

# Add debug script to project
add_debug_script() {
    local name="$1"
    local script="$2"
    
    init_projects_file
    
    local tmp
    tmp=$(mktemp)
    jq --arg name "$name" \
       --arg script "$script" \
       '.projects[$name].debug_scripts += [$script] | .projects[$name].debug_scripts |= unique' \
       "$PROJECTS_FILE" > "$tmp" && mv "$tmp" "$PROJECTS_FILE"
}

# Remove a project from registry
unregister_project() {
    local name="$1"
    
    if ! project_exists "$name"; then
        error "Project not found: $name"
        return 1
    fi
    
    local tmp
    tmp=$(mktemp)
    jq --arg name "$name" 'del(.projects[$name])' "$PROJECTS_FILE" > "$tmp" \
        && mv "$tmp" "$PROJECTS_FILE"
    
    success "Unregistered project: $name"
}

# List all projects
list_projects() {
    init_projects_file
    jq -r '.projects | to_entries[] | "\(.key)\t\(.value.path)\t\(.value.build_mode)"' "$PROJECTS_FILE"
}

# Get all project names
get_project_names() {
    init_projects_file
    jq -r '.projects | keys[]' "$PROJECTS_FILE"
}

# Resolve project: name -> full path
# Checks: 1) registered name 2) direct path 3) path under /extensions
resolve_project() {
    local name_or_path="${1:-}"
    
    if [[ -z "$name_or_path" ]]; then
        # Try current directory
        if [[ -f "config.m4" ]] || [[ -f "config.w32" ]]; then
            pwd
            return 0
        fi
        error "Not in an extension directory and no project specified"
        return 1
    fi
    
    # Check if it's a registered project name
    local path
    path=$(get_project_path "$name_or_path")
    if [[ -n "$path" ]]; then
        echo "$path"
        return 0
    fi
    
    # Check if it's a direct path
    if [[ -d "$name_or_path" ]]; then
        echo "$name_or_path"
        return 0
    fi
    
    # Check in extensions directory
    if [[ -d "$EXTENSIONS_DIR/$name_or_path" ]]; then
        echo "$EXTENSIONS_DIR/$name_or_path"
        return 0
    fi
    
    # Check nested structure (project_name/project_name)
    if [[ -d "$EXTENSIONS_DIR/$name_or_path/$name_or_path" ]]; then
        echo "$EXTENSIONS_DIR/$name_or_path/$name_or_path"
        return 0
    fi
    
    error "Project not found: $name_or_path"
    return 1
}

# Get project name from path or registered name
get_extension_name() {
    local name_or_path="$1"
    
    # If it's a registered project, get the basename of path
    if project_exists "$name_or_path"; then
        local path
        path=$(get_project_path "$name_or_path")
        basename "$path"
    else
        # Just use basename of path
        basename "$name_or_path"
    fi
}
