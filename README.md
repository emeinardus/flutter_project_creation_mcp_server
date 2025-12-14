# Flutter Architect MCP Server

An intelligent MCP server that enables AI (Claude in this case, but every other Client with MCP Support should work) to create, analyze, fix, and run Flutter projects with Clean Architecture patterns. The MCP Server always runs locally in stdio mode.

**Platform Support** :
Currently tested only on Windows. macOS and Linux support is implemented but untested.

## Table of Contents

- Features
- Prerequisites
- Installation
- Configuration
- Available Tools
- Usage Examples
- Project Structure

## Features

### Project Creation

- **Clean Architecture** structure with feature-based organization
- **Riverpod** state management (AsyncNotifier pattern)
- **Android Flavors** (dev/prod) pre-configured
- **Web Environment** support via dart-define
- Automatic dependency management

### Intelligent Analysis

- Deep project analysis with error detection
- Dependency conflict resolution
- Configuration validation
- Flutter environment diagnostics

### Auto-Repair

- Automatic error fixing
- Iterative validation loops
- Rollback on failed fixes
- Batch fix support

### Platform Support

- **Web**: Chrome with environment variables
- **Android**: Emulator auto-start with flavor support
- Hot reload enabled

## Prerequisites

### Required Software

1.  **Flutter SDK** (3.0.0 or higher)

```bash
   flutter --version
```

2.  **Dart SDK** (included with Flutter)

```bash
   dart --version
```

3.  **Claude Desktop** (latest version) or any equivalent which supports MCP
    - Download: [claude.ai](https://claude.ai/download)
4.  **Android Studio** (for Android development)
    - Required for Android emulator
    - Download: [developer.android.com](https://developer.android.com/studio)

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/flutter_mcp_server.git
cd flutter_mcp_server
```

### 2. Install Dependencies

```bash
dart pub get
```

### 3. Verify Installation

Test the server manually:

```bash
dart run bin/server.dart
```

You should see server startup logs. Press `Ctrl+C` to stop.

## Configuration

### Claude Desktop Setup

1. **Locate the config file:**

   **Windows:**

```
   %APPDATA%\Claude\claude_desktop_config.json
```

**macOS:**

```
   ~/Library/Application Support/Claude/claude_desktop_config.json
```

**Linux:**

```
   ~/.config/Claude/claude_desktop_config.json
```

2.  **Edit the config file:**

```json
{
  "mcpServers": {
    "flutter-architect": {
      "command": "dart",
      "args": [
        "run",
        "C:\\absolute\\path\\to\\flutter_mcp_server\\bin\\server.dart",
        "--mcp-stdio-mode"
      ]
    }
  }
}
```

**Important:** Replace `C:\\absolute\\path\\to\\flutter_mcp_server` with your actual path!

3. **Restart Claude Desktop**

   - Close Claude completely (check Task Manager on Windows)
   - Reopen Claude Desktop
   - The server should now be available

### Verify Connection

In Claude Desktop, ask:

```
Show me the Flutter MCP server info
```

Claude should respond with server details, available tools, and system information.

## Available Tools

### 1. Project Management

#### `create_flutter_project`

Creates a new Flutter project with Clean Architecture.

**Parameters:**

- `name` (required): Project name in snake_case
- `organization` (optional): Bundle identifier (default: `com.example.app`)
- `additional_dependencies` (optional): Array of pub packages

**Example:**

```
Create a Flutter project "recipe_app" with organization "com.kitchen.recipes"
and dependencies dio, freezed, go_router
```

#### `fix_flutter_project`

Repairs a Flutter project with clean and pub get.

**Parameters:**

- `path` (required): Project name or absolute path
- `deep_clean` (optional): Perform deep clean (default: false)

**Example:**

```
Fix my project "recipe_app" with deep clean
```

### 2. Intelligent Analysis

#### `analyze_flutter_project`

Deeply analyzes a Flutter project and returns comprehensive diagnostics.

**What it checks:**

- Project structure and file integrity
- Dependencies (pubspec.yaml, pubspec.lock)
- Configuration files (build.gradle, AndroidManifest.xml)
- Current errors and warnings
- Flutter environment details

**Parameters:**

- `path` (required): Project name or absolute path
- `include_code_samples` (optional): Include code snippets (default: false)

**Example:**

```
Analyze my project "recipe_app" and find all issues
```

#### `validate_flutter_project`

Validates that a project is in working condition.

**What it tests:**

- `flutter pub get` success
- `flutter analyze` passes
- Optional: Build compilation

**Parameters:**

- `path` (required): Project name or absolute path
- `run_build_check` (optional): Also check if project builds (default: false)

**Example:**

```
Validate "recipe_app" including build check
```

### 3. Code Modification

#### `apply_code_fix`

Applies a specific fix to a project file.

**Parameters:**

- `project_path` (required): Project name or absolute path
- `file_path` (required): Relative path from project root
- `content` (required): New complete file content
- `description` (required): Human-readable description of the fix
- `validate_after` (optional): Run pub get after fix (default: true)

**Example:**

```
After analyzing "recipe_app", apply this fix:
- File: pubspec.yaml
- Change riverpod version from ^2.5.1 to ^2.4.0
- Reason: Version conflict with Flutter SDK
```

#### `apply_batch_fixes`

Applies multiple fixes at once in a transaction.

**Parameters:**

- `project_path` (required): Project name or absolute path
- `fixes` (required): Array of fix objects with `file_path`, `content`, `description`

**Example:**

```
Apply these fixes to "recipe_app":
1. Update pubspec.yaml - downgrade riverpod
2. Update build.gradle - set compileSdk to 34
3. Fix main.dart - remove syntax error
```

#### `read_project_file`

Reads a specific file from the project.

**Parameters:**

- `project_path` (required): Project name or absolute path
- `file_path` (required): Relative path from project root

**Example:**

```
Read the build.gradle file from "recipe_app"
```

### 4. Platform Runners

#### `run_flutter_web`

Runs the Flutter project on Chrome.

**Parameters:**

- `path` (required): Project name or absolute path
- `environment` (optional): Environment variable (dev/prod, default: dev)

**Note:** Web doesn't support native flavors, only dart-define variables.

**Example:**

```
Start "recipe_app" for Web in prod environment
```

#### `run_flutter_android`

Runs the Flutter project on Android emulator.

**Features:**

- Auto-starts emulator if none running
- Waits for emulator boot
- Supports flavor selection

**Parameters:**

- `path` (required): Project name or absolute path
- `flavor` (optional): Build flavor (dev/prod, default: dev)
- `emulator` (optional): Specific emulator name

**Example:**

```
Start "recipe_app" on Android with prod flavor
```

#### `list_emulators`

Lists all available Android emulators.

**Example:**

```
Show me available Android emulators
```

### 5. Server Management

#### `get_server_info`

Displays server configuration and status.

**Example:**

```
Show me the Flutter MCP server info
```

#### `shutdown_server`

Gracefully shuts down the MCP server.

**Parameters:**

- `confirm` (optional): Confirmation flag (default: true)

**Example:**

```
Shutdown the MCP server
```

or simply:

```
Disconnect
```

## Usage Example

### Example: Create and Run a New Project

**Simple prompt:**

```
Create a Flutter project "todo_app" with dio and go_router,
validate it, and start it on Web in dev environment.
Do everything automatically.
```

**What Claude does:**

1. Calls `create_flutter_project(name: 'todo_app', additional_dependencies: ['dio', 'go_router'])`
2. Calls `validate_flutter_project(path: 'todo_app')`
3. Calls `run_flutter_web(path: 'todo_app', environment: 'dev')`

## Project Structure

### Generated Flutter Projects

```
my_flutter_app/
├── lib/
│   ├── app/
│   │   ├── core/              # Shared utilities
│   │   ├── config/            # App configuration
│   │   └── providers/         # Global Riverpod providers
│   │
│   ├── features/              # Feature-based modules
│   │   └── feature_template/
│   │       ├── domain/        # Business logic (entities, repositories)
│   │       ├── data/          # Data layer (repository implementations)
│   │       ├── application/   # Use cases
│   │       └── presentation/  # UI (screens, widgets, notifiers)
│   │
│   └── main.dart              # Entry point
│
├── android/
│   └── app/
│       └── build.gradle       # Flavor configuration (dev/prod)
│
├── .env.dev                   # Development environment
├── .env.prod                  # Production environment
├── .gitignore
└── pubspec.yaml
```

### Clean Architecture Layers

```
User Interaction (UI)
       ↓
Presentation Layer (Notifiers, Widgets)
       ↓
Application Layer (Use Cases) ← Business Logic
       ↓
Domain Layer (Entities, Repository Interfaces)
       ↓
Data Layer (Repository Implementations)
       ↓
External Sources (API, Database)
```
