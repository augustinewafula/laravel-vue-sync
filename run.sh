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

# Initialize default values
NON_INTERACTIVE=false
update_backend_choice="n"
update_frontend_choice="n"
laravel_commands_choice="n"
RUN_MIGRATE="n"
RUN_QUEUE_RESTART="n"
RUN_OPTIMIZE_CLEAR_AND_CACHE="n"
RUN_COMPOSER_INSTALL="n"
RUN_DUMP_AUTOLOAD="n"
FRONTEND_BUILD_TOOL="yarn"

# Initialize tracking arrays
declare -A backend_changes
declare -A frontend_changes
declare -A laravel_commands_run
declare -A frontend_builds_run

# Function to show help message
show_help() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --help                    Show this help message"
    echo "  --non-interactive         Run in non-interactive mode"
    echo "  --update-backend          Update backend"
    echo "  --update-frontend         Update frontend"
    echo "  --frontend-tool=TOOL      Specify frontend build tool (npm or yarn)"
    echo "  --run-migrations          Run database migrations"
    echo "  --restart-queue           Restart queue workers"
    echo "  --optimize-cache          Run optimize:clear and cache commands"
    echo "  --composer-install        Run composer install"
    echo "  --composer-dump-autoload  Run composer dump-autoload"
    echo "  --all-laravel-commands    Enable all Laravel commands"
    echo "  --skip-git-prompt         Skip git change prompts (auto-discard)"
    echo
    echo "Examples:"
    echo "  $0 --non-interactive --update-frontend --frontend-tool=yarn"
    echo "  $0 --update-backend --all-laravel-commands"
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
        --update-backend)
            update_backend_choice="y"
            ;;
        --update-frontend)
            update_frontend_choice="y"
            ;;
        --frontend-tool=*)
            FRONTEND_BUILD_TOOL="${1#*=}"
            if [[ ! "$FRONTEND_BUILD_TOOL" =~ ^(npm|yarn)$ ]]; then
                echo "Error: Frontend tool must be either 'npm' or 'yarn'"
                exit 1
            fi
            ;;
        --run-migrations)
            RUN_MIGRATE="y"
            laravel_commands_choice="y"
            ;;
        --restart-queue)
            RUN_QUEUE_RESTART="y"
            laravel_commands_choice="y"
            ;;
        --optimize-cache)
            RUN_OPTIMIZE_CLEAR_AND_CACHE="y"
            laravel_commands_choice="y"
            ;;
        --composer-install)
            RUN_COMPOSER_INSTALL="y"
            laravel_commands_choice="y"
            ;;
        --composer-dump-autoload)
            RUN_DUMP_AUTOLOAD="y"
            laravel_commands_choice="y"
            ;;
        --all-laravel-commands)
            laravel_commands_choice="y"
            RUN_MIGRATE="y"
            RUN_QUEUE_RESTART="y"
            RUN_OPTIMIZE_CLEAR_AND_CACHE="y"
            RUN_COMPOSER_INSTALL="y"
            RUN_DUMP_AUTOLOAD="y"
            ;;
        --skip-git-prompt)
            SKIP_GIT_PROMPT=true
            ;;
        *)
            echo "Unknown parameter: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
    shift
done

# Non-interactive mode adjustments
if [ "$NON_INTERACTIVE" = true ]; then
    # Backend logic if --update-backend is explicitly passed
    if [[ $update_backend_choice == "y" ]]; then
        if [[ $laravel_commands_choice == "y" ]]; then
            [[ $RUN_MIGRATE == "n" ]] && RUN_MIGRATE="y"
            [[ $RUN_QUEUE_RESTART == "n" ]] && RUN_QUEUE_RESTART="y"
            [[ $RUN_OPTIMIZE_CLEAR_AND_CACHE == "n" ]] && RUN_OPTIMIZE_CLEAR_AND_CACHE="y"
            [[ $RUN_COMPOSER_INSTALL == "n" ]] && RUN_COMPOSER_INSTALL="y"
            [[ $RUN_DUMP_AUTOLOAD == "n" ]] && RUN_DUMP_AUTOLOAD="y"
        fi
    fi

    # Default frontend tool if not specified
    [[ $update_frontend_choice == "y" ]] && [[ -z "$FRONTEND_BUILD_TOOL" ]] && FRONTEND_BUILD_TOOL="yarn"

    # Skip git prompt in non-interactive mode
    SKIP_GIT_PROMPT=true
fi

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

        if [ "$SKIP_GIT_PROMPT" = true ]; then
            echo "Automatically discarding local changes (excluding storage)..."
            git checkout HEAD -- $(git ls-files -m | grep -v '^storage/')
            git clean -fd --exclude=storage/
            changes_detected=2
        else
            read -p "Discard local changes (excluding storage) and pull from remote? [y/N]: " discard_choice </dev/tty
            if [[ $discard_choice =~ ^[Yy]$ ]]; then
                git checkout HEAD -- $(git ls-files -m | grep -v '^storage/')
                git clean -fd --exclude=storage/
                changes_detected=2
            else
                echo "Local changes retained. Proceeding with git pull."
            fi
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
    local project_name=$(basename "$path")
    backend_changes["$project_name"]=""
    
    handle_git "$path"
    local git_status=$?
    
    # Track git changes
    case $git_status in
        0) backend_changes["$project_name"]+="No changes detected. ";;
        1) backend_changes["$project_name"]+="Local changes retained. ";;
        2) backend_changes["$project_name"]+="Changes pulled from remote. ";;
    esac
    
    # Track Laravel commands
    local commands_run=""
    [[ $RUN_OPTIMIZE_CLEAR_AND_CACHE =~ ^[Yy]$ ]] && {
        php artisan optimize:clear
        php artisan config:cache
        php artisan route:cache
        php artisan view:cache
        commands_run+="optimize and cache, "
    }
    
    [[ $RUN_MIGRATE =~ ^[Yy]$ ]] && { php artisan migrate --force; commands_run+="migration, "; }
    [[ $RUN_QUEUE_RESTART =~ ^[Yy]$ ]] && { php artisan queue:restart; commands_run+="queue restart, "; }
    [[ $RUN_COMPOSER_INSTALL =~ ^[Yy]$ ]] && { composer install --no-interaction; commands_run+="composer install, "; }
    [[ $RUN_DUMP_AUTOLOAD =~ ^[Yy]$ ]] && { composer dumpautoload; commands_run+="composer dump-autoload, "; }
    
    [[ -n "$commands_run" ]] && laravel_commands_run["$project_name"]="${commands_run%, }"
}

# Function to update frontend
update_frontend() {
    local path=$1
    local project_name=$(basename "$path")
    frontend_changes["$project_name"]=""
    
    handle_git "$path"
    local git_status=$?
    
    # Track git changes
    case $git_status in
        0) frontend_changes["$project_name"]+="No changes detected. ";;
        1) frontend_changes["$project_name"]+="Local changes retained. ";;
        2) frontend_changes["$project_name"]+="Changes pulled from remote. ";;
    esac
    
    # Skip build if no changes detected
    if [[ $git_status -ne 2 ]]; then
        frontend_changes["$project_name"]+="Build skipped."
        return
    fi

    # Check if deploy.sh exists and track custom deployment
    if [[ -f "$path/deploy.sh" ]]; then
        echo "Found deploy.sh in $path. Using it for deployment..."
        chmod +x "$path/deploy.sh"
        "$path/deploy.sh"
        frontend_builds_run["$project_name"]="Custom deploy script"
        return
    fi

    # Track standard build process
    case $FRONTEND_BUILD_TOOL in
        yarn)
            echo "Building frontend at $path using Yarn..."
            (cd "$path" && yarn && yarn build)
            frontend_builds_run["$project_name"]="Yarn build"
            ;;
        npm)
            echo "Building frontend at $path using NPM..."
            (cd "$path" && npm install && npm run build)
            frontend_builds_run["$project_name"]="NPM build"
            ;;
        *)
            echo "Invalid build tool. Skipping build at $path."
            ;;
    esac
}

# Only prompt for options if not in non-interactive mode and not specified via command line
if [ "$NON_INTERACTIVE" = false ]; then
    # Only prompt for backend if not specified via command line
    [[ $update_backend_choice == "n" ]] && read -p "Update Backend? [y/N]: " update_backend_choice
    [[ $update_frontend_choice == "n" ]] && read -p "Update Frontend? [y/N]: " update_frontend_choice

    # Only prompt for Laravel commands if updating backend and not specified via command line
    if [[ $update_backend_choice =~ ^[Yy]$ ]] && [[ $laravel_commands_choice == "n" ]]; then
        read -p "Run Laravel commands? [y/N]: " laravel_commands_choice

        if [[ $laravel_commands_choice =~ ^[Yy]$ ]]; then
            [[ $RUN_MIGRATE == "n" ]] && read -p "Run 'php artisan migrate'? [y/N]: " RUN_MIGRATE
            [[ $RUN_QUEUE_RESTART == "n" ]] && read -p "Run 'php artisan queue:restart'? [y/N]: " RUN_QUEUE_RESTART
            [[ $RUN_OPTIMIZE_CLEAR_AND_CACHE == "n" ]] && read -p "Run 'php artisan optimize:clear' and caching? [y/N]: " RUN_OPTIMIZE_CLEAR_AND_CACHE
            [[ $RUN_COMPOSER_INSTALL == "n" ]] && read -p "Run 'composer install'? [y/N]: " RUN_COMPOSER_INSTALL
            [[ $RUN_DUMP_AUTOLOAD == "n" ]] && read -p "Run 'composer dumpautoload'? [y/N]: " RUN_DUMP_AUTOLOAD
        fi
    fi

    # Frontend build tool choice if not specified via command line
    if [[ $update_frontend_choice =~ ^[Yy]$ ]] && [[ -z "$FRONTEND_BUILD_TOOL" ]]; then
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
fi

# Automatically limit Node memory to 1024MB if system RAM is 1GB or less
total_memory=$(free -m | awk '/^Mem:/{print $2}')
if (( total_memory <= 1024 )); then
    echo "Limiting Node memory to 1024MB due to low available RAM ($total_memory MB detected)."
    export NODE_OPTIONS=--max-old-space-size=1024
fi

# Process each project
jq -c '.[]' "$PROJECTS_FILE" | while read -r project; do
    FRONTEND_PATH=$(echo "$project" | jq -r '.frontend_path // empty')
    BACKEND_PATH=$(echo "$project" | jq -r '.backend_path // empty')

    [[ $update_backend_choice =~ ^[Yy]$ ]] && [ -n "$BACKEND_PATH" ] && check_path "$BACKEND_PATH" && update_backend "$BACKEND_PATH"
    [[ $update_frontend_choice =~ ^[Yy]$ ]] && [ -n "$FRONTEND_PATH" ] && check_path "$FRONTEND_PATH" && update_frontend "$FRONTEND_PATH"
done

# Reset NODE_OPTIONS if it was set
if [[ -n $NODE_OPTIONS ]]; then
    unset NODE_OPTIONS
fi

# Print summary of all changes
print_summary() {
    echo -e "\n=== Update Summary ==="
    
    # Print backend updates
    if [[ ${#backend_changes[@]} -gt 0 ]]; then
        echo -e "\nBackend Updates:"
        for project in "${!backend_changes[@]}"; do
            echo "- $project:"
            echo "  * ${backend_changes[$project]}"
            [[ -n "${laravel_commands_run[$project]}" ]] && echo "  * Commands run: ${laravel_commands_run[$project]}"
        done
    fi
    
    # Print frontend updates
    if [[ ${#frontend_changes[@]} -gt 0 ]]; then
        echo -e "\nFrontend Updates:"
        for project in "${!frontend_changes[@]}"; do
            echo "- $project:"
            echo "  * ${frontend_changes[$project]}"
            [[ -n "${frontend_builds_run[$project]}" ]] && echo "  * Build: ${frontend_builds_run[$project]}"
        done
    fi
}

# Modify the final line of the script:
print_summary
echo -e "\nAll projects updated successfully!"