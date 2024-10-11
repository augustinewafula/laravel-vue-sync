#!/bin/bash

# Check for jq installation
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed."
    exit 1
fi

# Define the JSON files
PROJECTS_FILE="projects.json"
ENV_UPDATES_FILE="env-updates.json"

# Ensure the projects file exists
[ -f "$PROJECTS_FILE" ] || { echo "Projects file not found!"; exit 1; }

# Initialize default values
NON_INTERACTIVE=false

# Function to show help message
show_help() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --help              Show this help message"
    echo "  --non-interactive   Run in non-interactive mode"
    echo "  --env-file=FILE     Specify custom env updates file (default: env-updates.json)"
    exit 0
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            ;;
        --non-interactive)
            NON_INTERACTIVE=true
            ;;
        --env-file=*)
            ENV_UPDATES_FILE="${1#*=}"
            ;;
        *)
            echo "Unknown parameter: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
    shift
done

# Function to check if a key exists in .env file
check_env_key() {
    local env_file=$1
    local key=$2
    grep -q "^${key}=" "$env_file"
    return $?
}

# Function to update or add a single environment variable
update_env_value() {
    local env_file=$1
    local key=$2
    local value=$3
    local backup_file="${env_file}.backup"

    # Create backup of original file
    cp "$env_file" "$backup_file"

    if check_env_key "$env_file" "$key"; then
        # Key exists, update it
        sed -i "s|^${key}=.*|${key}=${value}|" "$env_file"
    else
        # Key doesn't exist, append it
        echo "${key}=${value}" >> "$env_file"
    fi
}

# Function to handle environment updates for a project path
handle_env_updates() {
    local project_path=$1
    local env_type=$2  # 'frontend' or 'backend'

    local env_file="${project_path}/.env"
    local env_example="${project_path}/.env.example"

    # Check if .env file exists
    if [ ! -f "$env_file" ]; then
        if [ -f "$env_example" ]; then
            cp "$env_example" "$env_file"
            echo "Created new .env file from .env.example in $project_path"
        else
            echo "Error: No .env or .env.example file found in $project_path"
            return 1
        fi
    fi

    # Check if env updates file exists
    if [ ! -f "$ENV_UPDATES_FILE" ]; then
        echo "Error: Environment update file $ENV_UPDATES_FILE not found."
        return 1
    fi

    # Apply environment updates from JSON file
    echo "Updating environment variables from $ENV_UPDATES_FILE for $env_type in $project_path..."
    
    jq -r --arg type "$env_type" \
       '.[$type] // {} | to_entries[] | "\(.key)=\(.value)"' "$ENV_UPDATES_FILE" | \
    while IFS='=' read -r key value; do
        if [ -n "$key" ] && [ -n "$value" ]; then
            update_env_value "$env_file" "$key" "$value"
            echo "Updated $key in $env_file"
        else
            echo "Warning: Skipped empty or invalid key/value for $env_type"
        fi
    done

    # Interactive updates if not in non-interactive mode
    if [ "$NON_INTERACTIVE" = false ]; then
        local update_more="y"
        while [[ $update_more =~ ^[Yy]$ ]]; do
            read -p "Enter environment variable key to update: " env_key
            read -p "Enter value for $env_key: " env_value
            
            if [ -n "$env_key" ]; then
                if update_env_value "$env_file" "$env_key" "$env_value"; then
                    echo "Updated $env_key in $env_file"
                else
                    echo "Error: Failed to update $env_key in $env_file"
                fi
            fi
            
            read -p "Update another variable? [y/N]: " update_more
        done
    fi
}

# Process each project
jq -c '.[]' "$PROJECTS_FILE" | while read -r project; do
    FRONTEND_PATH=$(echo "$project" | jq -r '.frontend_path // empty')
    BACKEND_PATH=$(echo "$project" | jq -r '.backend_path // empty')

    # Handle frontend environment if path exists
    [ -n "$FRONTEND_PATH" ] && [ -d "$FRONTEND_PATH" ] && handle_env_updates "$FRONTEND_PATH" "frontend"

    # Handle backend environment if path exists
    [ -n "$BACKEND_PATH" ] && [ -d "$BACKEND_PATH" ] && handle_env_updates "$BACKEND_PATH" "backend"
done

echo "Environment updates completed for all projects!"