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

# Function to handle git operations and check for changes after git pull
handle_git() {
    local path=$1
    cd "$path" || return
    local changes_detected=0

    # Check for local changes excluding the storage directory
    if git status --porcelain | grep -v '^?? storage/' &> /dev/null; then
        echo "Local changes detected in $path."
        changes_detected=1

        # Show changed files excluding storage
        echo "Changed files (excluding storage):"
        git status --porcelain | grep -v '^?? storage/'

        read -p "Discard local changes (excluding storage) and pull from remote? [y/N]: " discard_choice </dev/tty

        if [[ $discard_choice =~ ^[Yy]$ ]]; then
            # Discard local changes excluding storage
            git checkout HEAD -- $(git ls-files -m | grep -v '^storage/')
            git clean -fd --exclude=storage/
            changes_detected=2
        else
            echo "Local changes retained. Proceeding with git pull."
        fi
    else
        echo "No local changes detected in $path."
    fi

    # Perform git pull and capture output
    local git_pull_output
    git_pull_output=$(git pull)

    # Check if git pull resulted in changes
    if [[ $git_pull_output == *"Already up to date."* ]]; then
        echo "No changes after git pull in $path."
    else
        echo "Changes detected after git pull in $path."
        changes_detected=2
    fi

    # Restore permissions on storage folder after operations
    chmod -R 775 "${path}/storage"
    chown -R www-data:www-data "${path}/storage"

    return $changes_detected
}

# Function to update Laravel backend
update_backend() {
    local path=$1
    handle_git "$path"
    
    [[ $RUN_OPTIMIZE_CLEAR_AND_CACHE =~ ^[Yy]$ ]] && {
        php artisan optimize:clear
        php artisan config:cache
        php artisan route:cache
        php artisan view:cache
    }
    
    [[ $RUN_MIGRATE =~ ^[Yy]$ ]] && php artisan migrate --force
    [[ $RUN_QUEUE_RESTART =~ ^[Yy]$ ]] && php artisan queue:restart
    [[ $RUN_COMPOSER_INSTALL =~ ^[Yy]$ ]] && composer install
    [[ $RUN_DUMP_AUTOLOAD =~ ^[Yy]$ ]] && composer dumpautoload
}


# Function to update frontend
update_frontend() {
    local path=$1
    handle_git "$path"
    local git_status=$?

    # Skip build if no changes detected after git pull (git_status = 0 or 1)
    if [[ $git_status -ne 2 ]]; then
        echo "Skipping build process for $path due to no changes after git pull."
        return
    fi

    # Check if deploy.sh exists in the root folder of the project
    if [[ -f "$path/deploy.sh" ]]; then
        echo "Found deploy.sh in $path. Using it for deployment..."
        # Make sure deploy.sh is executable and then run it
        chmod +x "$path/deploy.sh"
        "$path/deploy.sh"
        return
    fi

    # Proceed with frontend build if no deploy.sh is found
    case $FRONTEND_BUILD_TOOL in
        yarn)
            echo "Building frontend at $path using Yarn..."
            (cd "$path" && yarn && yarn build)
            ;;
        npm)
            echo "Building frontend at $path using NPM..."
            (cd "$path" && npm install && npm run build)
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
    read -p "Run 'php artisan optimize:clear' followed by caching configurations, routes, and views? [y/N]: " RUN_OPTIMIZE_CLEAR_AND_CACHE
    read -p "Run 'composer install'? [y/N]: " RUN_COMPOSER_INSTALL
    read -p "Run 'composer dumpautoload'? [y/N]: " RUN_DUMP_AUTOLOAD
fi

# Frontend build tool choice simplified
if [[ $update_frontend_choice =~ ^[Yy]$ ]]; then
    echo "Select the tool for frontend builds:"
    echo "  1) Yarn"
    echo "  2) NPM"
    read -p "Enter your choice (1 or 2): " build_tool_choice

    case $build_tool_choice in
        1)
            FRONTEND_BUILD_TOOL="yarn"
            ;;
        2)
            FRONTEND_BUILD_TOOL="npm"
            ;;
        *)
            echo "Invalid choice. Defaulting to npm."
            FRONTEND_BUILD_TOOL="npm"
            ;;
    esac
fi

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
