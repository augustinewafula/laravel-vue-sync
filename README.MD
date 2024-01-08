# LaraVueSync

## Introduction
LaraVueSync is a Bash script designed to automate the updating process for projects built with Laravel (backend) and Vue.js (frontend). It handles updates for multiple instances of such projects hosted on a single server, streamlining the process of running git pulls and various Laravel-specific commands for the backend, and build processes for the frontend.

## Prerequisites
- Bash shell
- `git`, `jq` installed (for JSON processing)
- Laravel and Vue.js environments set up for backend and frontend respectively

## Installation
1. Clone the LaraVueSync repository to your local machine.
2. Give execute permission to the script:
   ```bash
   chmod +x RUN.sh
   ```

## Configuration
1. Create a `projects.json` file in the same directory as the script. This file should list all the projects with their respective frontend and backend paths.
   ```json
   {
     "project1": {
       "frontend_path": "/path/to/project1_frontend",
       "backend_path": "/path/to/project1_backend"
     },
     "project2": {
       "frontend_path": "/path/to/project2_frontend",
       "backend_path": "/path/to/project2_backend"
     }
     // Add more projects as needed
   }
   ```
2. Ensure that `projects.json` is not tracked by Git. Add it to your `.gitignore` file:
   ```
   projects.json
   ```

## Usage
Run the script from the terminal:
```bash
./run.sh
```
Follow the on-screen prompts to complete the update process for each project.

## Note
This script is customizable and can be modified to suit specific project requirements or deployment workflows.

EOF

echo "README.md has been generated."
