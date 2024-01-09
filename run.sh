#!/bin/bash

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed."
    echo "Please install jq to process JSON files."
    echo "On Ubuntu/Debian: sudo apt-get install jq"
    echo "On Red Hat/CentOS: sudo yum install jq"
    echo "On macOS: brew install jq"
    exit 1
fi

# Define the JSON file containing project paths
PROJECTS_FILE="projects.json"

# Check if the projects file exists
if [ ! -f "$PROJECTS_FILE" ]; then
    echo "Projects file not found!"
    exit 1
fi

# Function to check if a path is valid
check_path() {
    if [ ! -d "$1" ]; then
        echo "Path $1 not found!"
        return 1
    fi
    return 0
}

# Check all project paths before proceeding
ALL_PATHS_VALID="yes"
jq -c '.[]' $PROJECTS_FILE | while read -r project; do
    FRONTEND_PATH=$(echo $project | jq -r '.frontend_path // empty')
    BACKEND_PATH=$(echo $project | jq -r '.backend_path // empty')
    
    if [ -n "$FRONTEND_PATH" ] && ! check_path "$FRONTEND_PATH"; then
        ALL_PATHS_VALID="no"
        break
    fi
    if [ -n "$BACKEND_PATH" ] && ! check_path "$BACKEND_PATH"; then
        ALL_PATHS_VALID="no"
        break
    fi
done

if [ "$ALL_PATHS_VALID" != "yes" ]; then
    echo "One or more paths are invalid. Please check your projects.json file."
    exit 1
fi

# Initialize flags for Laravel commands
RUN_MIGRATE="n"
RUN_QUEUE_RESTART="n"
RUN_CACHE_CLEAR="n"
RUN_CONFIG_CLEAR="n"
RUN_COMPOSER_INSTALL="n"
RUN_DUMP_AUTOLOAD="n"

# Initialize variable for frontend build tool
FRONTEND_BUILD_TOOL=""

# Ask user for Laravel commands to run for all projects
read -p "Run 'php artisan migrate' for all projects? [y/N]: " RUN_MIGRATE
read -p "Run 'php artisan queue:restart' for all projects? [y/N]: " RUN_QUEUE_RESTART
read -p "Run 'php artisan cache:clear' for all projects? [y/N]: " RUN_CACHE_CLEAR
read -p "Run 'php artisan config:clear' for all projects? [y/N]: " RUN_CONFIG_CLEAR
read -p "Run 'composer install' for all backend projects? [y/N]: " RUN_COMPOSER_INSTALL
read -p "Run 'composer dumpautoload' for all projects? [y/N]: " RUN_DUMP_AUTOLOAD

# Ask user for frontend build tool choice to apply to all projects
read -p "Use yarn or npm for frontend builds on all projects? [yarn/npm]: " FRONTEND_BUILD_TOOL

# Read each project and update
jq -c '.[]' $PROJECTS_FILE | while read -r project; do
    FRONTEND_PATH=$(echo $project | jq -r '.frontend_path // empty')
    BACKEND_PATH=$(echo $project | jq -r '.backend_path // empty')

    # Update Backend
    if [ -n "$BACKEND_PATH" ] && check_path "$BACKEND_PATH"; then
        echo "Updating backend at $BACKEND_PATH..."
        cd $BACKEND_PATH
        git pull
        echo "Backend at $BACKEND_PATH updated."

        # Run Laravel commands based on user's choice
        if [ "$RUN_MIGRATE" == "Y" ] || [ "$RUN_MIGRATE" == "y" ]; then
            echo "Running migration at $BACKEND_PATH..."
            php artisan migrate
            echo "Migration completed at $BACKEND_PATH."
        fi
        if [ "$RUN_QUEUE_RESTART" == "Y" ] || [ "$RUN_QUEUE_RESTART" == "y" ]; then
            echo "Restarting queue at $BACKEND_PATH..."
            php artisan queue:restart
            echo "Queue restarted at $BACKEND_PATH."
        fi
        if [ "$RUN_CACHE_CLEAR" == "Y" ] || [ "$RUN_CACHE_CLEAR" == "y" ]; then
            echo "Clearing cache at $BACKEND_PATH..."
            php artisan cache:clear
            echo "Cache cleared at $BACKEND_PATH."
        fi
        if [ "$RUN_CONFIG_CLEAR" == "Y" ] || [ "$RUN_CONFIG_CLEAR" == "y" ]; then
            echo "Clearing config at $BACKEND_PATH..."
            php artisan config:clear
            echo "Config cleared at $BACKEND_PATH."
        fi
        if [ "$RUN_COMPOSER_INSTALL" == "Y" ] || [ "$RUN_COMPOSER_INSTALL" == "y" ]; then
            echo "Running composer install at $BACKEND_PATH..."
            composer install
            echo "Composer install completed at $BACKEND_PATH."
        fi
        if [ "$RUN_DUMP_AUTOLOAD" == "Y" ] || [ "$RUN_DUMP_AUTOLOAD" == "y" ]; then
            echo "Running composer dumpautoload at $BACKEND_PATH..."
            composer dumpautoload
            echo "Composer dumpautoload completed at $BACKEND_PATH."
        fi
    fi

    # Update Frontend
    if [ -n "$FRONTEND_PATH" ] && check_path "$FRONTEND_PATH"; then
        echo "Updating frontend at $FRONTEND_PATH..."
        cd $FRONTEND_PATH
        git pull
        echo "Frontend at $FRONTEND_PATH updated."

        # Use the chosen frontend build tool for all projects
        if [ "$FRONTEND_BUILD_TOOL" == "yarn" ]; then
            echo "Building frontend at $FRONTEND_PATH using Yarn..."
            yarn
            yarn build
            echo "Frontend built at $FRONTEND_PATH using Yarn."
        elif [ "$FRONTEND_BUILD_TOOL" == "npm" ]; then
            echo "Building frontend at $FRONTEND_PATH using NPM..."
            npm install
            npm run build
            echo "Frontend built at $FRONTEND_PATH using NPM."
        else
            echo "Invalid frontend build tool choice. Skipping build at $FRONTEND_PATH."
        fi
    fi
done

echo "All projects updated successfully!"
