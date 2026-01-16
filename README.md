# PED – PHP Extension Development Environment

A Docker-based development environment for building, testing, and debugging PHP extensions, with an integrated CLI toolset.

## Quick Start

```bash
# Start the environment
docker-compose up -d

# Download the wrapper script (optional, for host convenience)
curl -o ped https://raw.githubusercontent.com/hogyesn/php-extension-dev-docker/main/ped
chmod +x ped

# Create a new extension
./ped new my_extension

# Build it
./ped build my_extension

# Run tests
./ped test my_extension

# Debug it
./ped debug my_extension
```

## Docker Image

The prebuilt Docker image is available on Docker Hub:

- https://hub.docker.com/r/hogyesn/php-extension-dev

## What's Included

- **PHP** with development headers and debug symbols
- **Build tools:** gcc, make, autoconf, libtool
- **Debugging:** gdbserver for remote debugging
- **PED CLI:** Integrated command-line tool for extension development
- **Smart wrapper:** Auto-detects and manages containers

## PED CLI Commands

The PED CLI provides high-level commands for the full extension development lifecycle:

| Command | Description |
|---------|-------------|
| `ped new <name>` | Create a new extension skeleton |
| `ped build <name> [mode]` | Build extension (debug/prod) |
| `ped stub <name>` | Update stub file (regenerate arginfo) |
| `ped debug <name> [script]` | Start debugging session with gdbserver |
| `ped test <name>` | Run extension tests |
| `ped script <name> <project>` | Create a debug script |
| `ped list [-a\|--all]` | List projects (use -a for details) |
| `ped project <subcommand>` | Manage project configuration |

## Project Structure

```
php-extension-dev-docker/
├── extensions/          # Your extension source code
├── debug_scripts/       # PHP scripts for testing
├── scripts/             # Bash scripts used by the PED CLI
├── ped                  # Smart wrapper script (host)
├── Dockerfile           # Image definition
├── docker-compose.yml   # Container configuration
├── php.ini              # Optional custom PHP configuration
```

## Volume Mounts

The following directories are mounted for development:

- `./extensions` - Your extension source code
- `./debug_scripts` - Debug PHP scripts organized by project
- `./php.ini` (optional) - Custom PHP configuration

## Debugging Setup

### VS Code Configuration

1. **Copy debug binary to host:**
   ```bash
   docker cp php-extension-dev:/usr/local/php-bin/DEBUG/bin/php ./bin/php
   ```

2. **Create `.vscode/launch.json`:**
   ```json
   {
     "version": "0.2.0",
     "configurations": [
       {
         "name": "Debug PHP Extension",
         "type": "cppdbg",
         "request": "launch",
         "program": "${workspaceFolder}/bin/php",
         "miDebuggerServerAddress": "localhost:3333",
         "miDebuggerPath": "/usr/bin/gdb",
         "MIMode": "gdb"
       }
     ]
   }
   ```

3. **Start debugging:**
   ```bash
   # Start gdbserver
   ./ped debug my_extension
   
   # VS Code - Press F5
   ```

## Smart Wrapper Features

The `./ped` wrapper script includes:

- **Auto-detection:** Finds your container (docker-compose or docker run)
- **Auto-start:** Prompts to start container if none running
- **Version selection:** Choose PHP version tag when starting (8.1.x, 8.2.x, 8.3.x, latest, etc. See hub for available tags: https://hub.docker.com/r/hogyesn/php-extension-dev)
- **Stopped container handling:** Offers to restart or recreate
- **Directory creation:** Auto-creates required directories

## Example Workflow

```bash
# 1. Create extension
./ped new mjml

# 2. Edit your code
nano extensions/mjml/mjml.c
nano extensions/mjml/mjml.stub.php

# 3. Regenerate arginfo from stub
./ped stub mjml

# 4. Build
./ped build mjml

# 5. Run tests
./ped test mjml

# 6. Create debug script
./ped script test.php mjml
nano debug_scripts/mjml/test.php

# 7. Debug with VS Code
./ped debug mjml
# Then press F5 in VS Code
```

## Requirements

- Docker
- Docker Compose (optional, but recommended)
- VS Code with C/C++ extension (for debugging)
- GDB on host (for debugging)


## License

MIT License - See [LICENSE](LICENSE) file for details.

Copyright (c) 2026 hogyesn

## Notes

The ped CLI was quickly scaffolded with the help of AI-assisted coding tools and then reviewed and refined manually.
