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

# Function to handle environment updates for a project
handle_env_updates() {
    local path=$1
    local env_file="${path}/.env"
    local env_example="${path}/.env.example"
    local env_type=$2  # 'backend' or 'frontend'

    # Check if .env file exists
    if [ ! -f "$env_file" ]; then
        if [ -f "$env_example" ]; then
            cp "$env_example" "$env_file"
            echo "Created new .env file from .env.example"
        else
            echo "Error: No .env or .env.example file found in $path"
            return 1
        fi
    fi

    # Parse environment updates from JSON file if provided
    if [ -n "$ENV_UPDATES_FILE" ] && [ -f "$ENV_UPDATES_FILE" ]; then
        echo "Updating environment variables from file for $env_type..."
        
        # Use jq to extract and process environment variables for the specific type
        jq -r --arg type "$env_type" \
           '.[$type] // {} | to_entries[] | "\(.key)=\(.value)"' "$ENV_UPDATES_FILE" | \
        while IFS='=' read -r key value; do
            if [ -n "$key" ]; then
                update_env_value "$env_file" "$key" "$value"
                echo "Updated $key in $env_file"
            fi
        done
    fi

    # Interactive updates if not in non-interactive mode
    if [ "$NON_INTERACTIVE" = false ]; then
        local update_more="y"
        while [[ $update_more =~ ^[Yy]$ ]]; do
            read -p "Enter environment variable key to update: " env_key
            read -p "Enter value for $env_key: " env_value
            
            if [ -n "$env_key" ]; then
                update_env_value "$env_file" "$env_key" "$env_value"
                echo "Updated $env_key in $env_file"
            fi
            
            read -p "Update another variable? [y/N]: " update_more
        done
    fi
}