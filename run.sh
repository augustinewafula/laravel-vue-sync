#!/bin/bash

# Check for jq installation
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed."
    exit 1
fi

# Define the JSON file containing project paths
PROJECTS_FILE="projects.json"

# Ensure the projects file exists
[ -f "$PROJECTS_FILE" ] || { echo "Projects file not found!"; exit 1; }

# Function to check if a path is valid
check_path() {
    [ -d "$1" ] || { echo "Path $1 not found!"; return 1; }
}

# Function to handle git operations
handle_git() {
    local path=$1
    cd "$path" || return

    # Check for local changes using git status
    if git diff-index --quiet HEAD --; then
        echo "No local changes detected in $path."
    else
        echo "Local changes detected in $path."
        read -p "Discard local changes and pull from remote? [y/N]: " discard_choice
        if [[ $discard_choice =~ ^[Yy]$ ]]; then
            # Discard local changes
            git reset --hard HEAD
            git clean -fd
        else
            echo "Skipping git pull due to local changes at $path."
            return 1
        fi
    fi

    # Perform git pull
    if ! git pull; then
        echo "Error occurred while pulling from git at $path."
        return 1
    fi
}


# Function to update Laravel backend
update_backend() {
    local path=$1
    handle_git "$path"
    [[ $RUN_MIGRATE =~ ^[Yy]$ ]] && php artisan migrate
    [[ $RUN_QUEUE_RESTART =~ ^[Yy]$ ]] && php artisan queue:restart
    [[ $RUN_CACHE_CLEAR =~ ^[Yy]$ ]] && php artisan cache:clear
    [[ $RUN_CONFIG_CLEAR =~ ^[Yy]$ ]] && php artisan config:clear
    [[ $RUN_COMPOSER_INSTALL =~ ^[Yy]$ ]] && composer install
    [[ $RUN_DUMP_AUTOLOAD =~ ^[Yy]$ ]] && composer dumpautoload
}

# Function to update frontend
update_frontend() {
    local path=$1
    handle_git "$path"

    # Perform frontend build based on the chosen tool
    case $FRONTEND_BUILD_TOOL in
        yarn)
            echo "Building frontend at $path using Yarn..."
            yarn
            yarn build
            echo "Frontend built at $path using Yarn."
            ;;
        npm)
            echo "Building frontend at $path using NPM..."
            npm install
            npm run build
            echo "Frontend built at $path using NPM."
            ;;
        *)
            echo "Invalid build tool. Skipping build at $path."
            ;;
    esac
}

# Prompt for update options
read -p "Update Backend? [y/N]: " update_backend_choice
read -p "Update Frontend? [y/N]: " update_frontend_choice
[[ $update_backend_choice =~ ^[Yy]$ ]] && read -p "Run Laravel commands? [y/N]: " laravel_commands_choice

# Laravel commands prompt
if [[ $laravel_commands_choice =~ ^[Yy]$ ]]; then
    read -p "Run 'php artisan migrate'? [y/N]: " RUN_MIGRATE
    read -p "Run 'php artisan queue:restart'? [y/N]: " RUN_QUEUE_RESTART
    read -p "Run 'php artisan cache:clear'? [y/N]: " RUN_CACHE_CLEAR
    read -p "Run 'php artisan config:clear'? [y/N]: " RUN_CONFIG_CLEAR
    read -p "Run 'composer install'? [y/N]: " RUN_COMPOSER_INSTALL
    read -p "Run 'composer dumpautoload'? [y/N]: " RUN_DUMP_AUTOLOAD
fi

# Frontend build tool choice
[[ $update_frontend_choice =~ ^[Yy]$ ]] && read -p "Use yarn or npm for frontend builds? [yarn/npm]: " FRONTEND_BUILD_TOOL

# Node memory limit prompt (asked once)
if [[ $update_frontend_choice =~ ^[Yy]$ ]]; then
    read -p "Limit Node memory to 1024MB for frontend builds? [y/N]: " limit_memory_choice
    if [[ $limit_memory_choice =~ ^[Yy]$ ]]; then
        export NODE_OPTIONS=--max-old-space-size=1024
    fi
fi

# Process each project
jq -c '.[]' $PROJECTS_FILE | while read -r project; do
    FRONTEND_PATH=$(echo $project | jq -r '.frontend_path // empty')
    BACKEND_PATH=$(echo $project | jq -r '.backend_path // empty')

    [[ $update_backend_choice =~ ^[Yy]$ ]] && [ -n "$BACKEND_PATH" ] && check_path "$BACKEND_PATH" && update_backend "$BACKEND_PATH"
    [[ $update_frontend_choice =~ ^[Yy]$ ]] && [ -n "$FRONTEND_PATH" ] && check_path "$FRONTEND_PATH" && update_frontend "$FRONTEND_PATH"
done

# Reset NODE_OPTIONS if it was set
if [[ $limit_memory_choice =~ ^[Yy]$ ]]; then
    unset NODE_OPTIONS
fi

echo "All projects updated successfully!"
