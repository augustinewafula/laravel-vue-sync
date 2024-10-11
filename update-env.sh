#!/bin/bash

# Check for jq installation
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed."
    exit 1
fi

# Define the JSON files
PROJECTS_FILE="projects.json"
ENV_UPDATES_FILE="env-updates.json"

# Initialize default values
NON_INTERACTIVE=false
REVERT_MODE=false
LIST_BACKUPS=false
REMOVE_BACKUPS=false

# Function to show help message
show_help() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --help              Show this help message"
    echo "  --non-interactive   Run in non-interactive mode"
    echo "  --env-file=FILE     Specify custom env updates file (default: env-updates.json)"
    echo "  --revert           Revert .env files to their backups"
    echo "  --list-backups     List all available .env backups"
    echo "  --remove-backups   Remove all .env backup files"
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
        --revert)
            REVERT_MODE=true
            ;;
        --list-backups)
            LIST_BACKUPS=true
            ;;
        --remove-backups)
            REMOVE_BACKUPS=true
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

    # Create backup of original file if it doesn't exist
    [ -f "$backup_file" ] || cp "$env_file" "$backup_file"

    if check_env_key "$env_file" "$key"; then
        # Key exists, update it
        sed -i "s|^${key}=.*|${key}=${value}|" "$env_file"
    else
        # Key doesn't exist, append it
        echo "${key}=${value}" >> "$env_file"
    fi
}

# Function to handle backup operations
handle_backup() {
    local project_path=$1
    local operation=$2  # 'list', 'revert', or 'remove'
    local env_file="${project_path}/.env"
    local backup_file="${env_file}.backup"

    case $operation in
        list)
            if [ -f "$backup_file" ]; then
                echo "Backup exists for: $project_path"
                echo "  Original backup date: $(stat -c %y "$backup_file")"
            fi
            ;;
        revert)
            if [ -f "$backup_file" ]; then
                if cp "$backup_file" "$env_file"; then
                    echo "Successfully reverted .env file in: $project_path"
                else
                    echo "Failed to revert .env file in: $project_path"
                fi
            else
                echo "No backup file found for: $project_path"
            fi
            ;;
        remove)
            if [ -f "$backup_file" ]; then
                if rm "$backup_file"; then
                    echo "Removed backup file in: $project_path"
                else
                    echo "Failed to remove backup file in: $project_path"
                fi
            fi
            ;;
    esac
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
    
    while IFS='=' read -r key value; do
        if [ -n "$key" ] && [ -n "$value" ]; then
            # Remove any surrounding quotes from the value
            value=$(echo "$value" | sed -e 's/^"//' -e 's/"$//')
            update_env_value "$env_file" "$key" "$value"
            echo "Updated $key in $env_file"
        fi
    done < <(jq -r --arg type "$env_type" '.[$type] // {} | to_entries[] | "\(.key)=\(.value)"' "$ENV_UPDATES_FILE")

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

# Process each project based on the selected operation mode
process_projects() {
    local operation=$1
    
    while IFS= read -r project_path; do
        if [ -n "$project_path" ] && [ "$project_path" != "null" ]; then
            case $operation in
                update)
                    # Determine if it's a frontend or backend path and handle accordingly
                    if [[ "$project_path" == *"frontend"* ]]; then
                        [ -d "$project_path" ] && handle_env_updates "$project_path" "frontend"
                    elif [[ "$project_path" == *"backend"* ]]; then
                        [ -d "$project_path" ] && handle_env_updates "$project_path" "backend"
                    fi
                    ;;
                list|revert|remove)
                    [ -d "$project_path" ] && handle_backup "$project_path" "$operation"
                    ;;
            esac
        fi
    done < <(jq -r '.[] | (.frontend_path, .backend_path)' "$PROJECTS_FILE")
}

# Main execution logic
if [ "$LIST_BACKUPS" = true ]; then
    echo "Listing all .env backup files..."
    process_projects "list"
elif [ "$REVERT_MODE" = true ]; then
    echo "Reverting all .env files to their backups..."
    process_projects "revert"
elif [ "$REMOVE_BACKUPS" = true ]; then
    echo "Removing all .env backup files..."
    if [ "$NON_INTERACTIVE" = false ]; then
        read -p "Are you sure you want to remove all backup files? [y/N]: " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            echo "Operation cancelled."
            exit 0
        fi
    fi
    process_projects "remove"
else
    process_projects "update"
fi

echo "Operation completed!"