#!/bin/bash

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

# Function to extract project path from project.json
get_project_path() {
    local project_name=$1
    local env_type=$2
    local path_key

    # Determine if we are looking for frontend or backend path
    if [ "$env_type" = "frontend" ]; then
        path_key="frontend_path"
    elif [ "$env_type" = "backend" ]; then
        path_key="backend_path"
    else
        echo "Error: Invalid environment type. Use 'frontend' or 'backend'."
        return 1
    fi

    # Use jq to extract the path from project.json
    jq -r --arg project "$project_name" --arg key "$path_key" \
    '.[$project][$key] // empty' project.json
}

# Function to handle environment updates for a project
handle_env_updates() {
    local project_name=$1
    local env_type=$2  # 'frontend' or 'backend'

    # Get the path from project.json
    local project_path
    project_path=$(get_project_path "$project_name" "$env_type")

    if [ -z "$project_path" ]; then
        echo "Error: Project path not found for $project_name ($env_type)"
        return 1
    fi

    local env_file="${project_path}/.env"
    local env_example="${project_path}/.env.example"

    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is not installed. Please install it to use this script."
        return 1
    fi

    # Check if .env file exists
    if [ ! -f "$env_file" ]; then
        if [ -f "$env_example" ]; then
            cp "$env_example" "$env_file"
            echo "Created new .env file from .env.example"
        else
            echo "Error: No .env or .env.example file found in $project_path"
            return 1
        fi
    fi

    # Ensure ENV_UPDATES_FILE and NON_INTERACTIVE are set
    ENV_UPDATES_FILE="${ENV_UPDATES_FILE:-env-updates.json}"
    : "${NON_INTERACTIVE:=false}"

    # Parse environment updates from JSON file if provided
    if [ -f "$ENV_UPDATES_FILE" ]; then
        echo "Updating environment variables from $ENV_UPDATES_FILE for $env_type..."
        
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
    else
        echo "Error: Environment update file $ENV_UPDATES_FILE not found."
        return 1
    fi

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

# Main entry point for the script
main() {
    if [ $# -lt 2 ]; then
        echo "Usage: $0 <project-name> <env-type: frontend | backend>"
        exit 1
    fi

    local project_name=$1
    local env_type=$2

    handle_env_updates "$project_name" "$env_type"
}

# Execute the script
main "$@"
