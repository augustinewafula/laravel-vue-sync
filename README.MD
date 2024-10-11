# LaraVueSync

## Introduction
LaraVueSync is a Bash script designed to automate the updating process for projects built with Laravel (backend) and Vue.js/React (frontend). It handles updates for multiple instances of such projects hosted on a single server, streamlining the process of running git pulls, Laravel-specific commands, and frontend build processes.

## Prerequisites
- Bash shell
- `git` installed
- `jq` installed (for JSON processing)
- Laravel and Node.js environments set up for backend and frontend respectively

## Installation
1. Clone the LaraVueSync repository to your local machine.
2. Give execute permission to the script:
   ```bash
   chmod +x run.sh
   ```

## Configuration
Create a `projects.json` file in the same directory as the script. This file should list all the projects with their respective frontend and backend paths:
```json
[
  {
    "frontend_path": "/path/to/project1_frontend",
    "backend_path": "/path/to/project1_backend"
  },
  {
    "frontend_path": "/path/to/project2_frontend",
    "backend_path": "/path/to/project2_backend"
  }
]
```

## Usage

### Basic Usage
Run the script from the terminal:
```bash
./run.sh
```

### Command Line Options
```bash
Usage: ./run.sh [options]

Options:
  --help                    Show this help message
  --non-interactive         Run in non-interactive mode
  --update-backend         Update backend
  --update-frontend        Update frontend
  --frontend-tool=TOOL     Specify frontend build tool (npm or yarn)
  --run-migrations         Run database migrations
  --restart-queue          Restart queue workers
  --optimize-cache         Run optimize:clear and cache commands
  --composer-install       Run composer install
  --composer-dump-autoload Run composer dump-autoload
  --all-laravel-commands   Enable all Laravel commands
  --skip-git-prompt        Skip git change prompts (auto-discard)
```

### Examples
```bash
# Update frontend using yarn in non-interactive mode
./run.sh --non-interactive --update-frontend --frontend-tool=yarn

# Update backend with all Laravel commands
./run.sh --update-backend --all-laravel-commands
```

## Features

### Backend Operations
- Git pull with change detection
- Laravel artisan commands:
  - `migrate`
  - `queue:restart`
  - `optimize:clear`
  - `config:cache`
  - `route:cache`
  - `view:cache`
- Composer commands:
  - `composer install`
  - `composer dump-autoload`
- Automatic storage permissions management

### Frontend Operations
- Git pull with change detection
- Support for both npm and yarn
- Automatic build process
- Custom deployment script support via `deploy.sh`
- Automatic Node.js memory management for low-RAM systems

### General Features
- Non-interactive mode for automated deployments
- Selective updates (frontend/backend)
- Git change management with optional auto-discard
- Multiple project support via JSON configuration
- Storage directory permissions handling

## Automatic Memory Management
The script automatically limits Node.js memory usage to 1024MB when running on systems with 1GB RAM or less to prevent out-of-memory issues during builds.

## Custom Deployment Scripts
If a `deploy.sh` file exists in the root folder of a frontend project, the script will use it instead of the default build process. This allows for custom deployment logic when needed.

## Error Handling
- Checks for required dependencies (`jq`)
- Validates project paths
- Handles Git conflicts and local changes
- Manages storage directory permissions
- Provides clear error messages and status updates

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request.