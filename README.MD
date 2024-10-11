# LaraVueSync

## Introduction
LaraVueSync is a Bash script designed to automate the updating process for projects built with Laravel (backend) and Vue.js/React (frontend). It handles updates for multiple instances of such projects hosted on a single server, streamlining the process of running git pulls, Laravel-specific commands, frontend build processes, and environment variable management.

## Prerequisites
- Bash shell
- `git` installed
- `jq` installed (for JSON processing)
- Laravel and Node.js environments set up for backend and frontend respectively

## Installation
1. Clone the LaraVueSync repository to your local machine.
2. Give execute permission to the scripts:
   ```bash
   chmod +x run.sh update-env.sh
   ```

## Configuration

### Project Configuration
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

### Environment Updates Configuration
Create an `env-updates.json` file to specify environment variables for automated updates:
```json
{
  "backend": {
    "APP_DEBUG": "false",
    "QUEUE_CONNECTION": "redis",
    "CACHE_DRIVER": "redis"
  },
  "frontend": {
    "VITE_API_URL": "https://api.example.com",
    "VITE_APP_ENV": "production"
  }
}
```

## Usage

### Basic Usage
Run the main update script:
```bash
./run.sh
```

Run the environment update script:
```bash
./update-env.sh
```

### Command Line Options

#### Main Script (run.sh)
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

#### Environment Update Script (update-env.sh)
```bash
Usage: ./update-env.sh [options]

Options:
  --help                    Show this help message
  --non-interactive         Run in non-interactive mode
  --env-updates=FILE       Specify JSON file containing environment updates
  --update-backend         Update backend environment
  --update-frontend        Update frontend environment
  --create-env             Create .env from .env.example if missing
```

### Examples
```bash
# Update frontend using yarn in non-interactive mode
./run.sh --non-interactive --update-frontend --frontend-tool=yarn

# Update backend with all Laravel commands
./run.sh --update-backend --all-laravel-commands

# Update environment variables from file
./update-env.sh --env-updates=env-updates.json --update-backend --update-frontend

# Interactive environment updates for backend only
./update-env.sh --update-backend
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

### Environment Management
- Separate backend and frontend environment updates
- Support for automated updates via JSON configuration
- Interactive environment variable management
- Automatic .env file creation from .env.example
- Environment file backups before modifications
- Secure handling of sensitive information

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

## Environment Management Safety
- Creates backups of .env files before modifications
- Validates environment variable keys and values
- Maintains existing file formatting
- Provides clear feedback on all operations
- Supports both automated and interactive updates

## Error Handling
- Checks for required dependencies (`jq`)
- Validates project paths
- Handles Git conflicts and local changes
- Manages storage directory permissions
- Provides clear error messages and status updates
- Validates environment update configurations

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request.

## Security Considerations
- Keep your `env-updates.json` file secure and outside of version control
- Use appropriate file permissions for environment files
- Regularly review and audit environment variables
- Consider using encryption for sensitive environment data