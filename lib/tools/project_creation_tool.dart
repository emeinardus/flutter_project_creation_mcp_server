import 'dart:io';
import 'package:flutter_mcp_server/config/server_config.dart';
import 'package:flutter_mcp_server/services/flutter_service.dart';
import 'package:flutter_mcp_server/services/path_services.dart';
import 'package:flutter_mcp_server/templates/gradle_template.dart';
import 'package:flutter_mcp_server/templates/main_template.dart';
import 'package:flutter_mcp_server/templates/pubspec_template.dart';
import 'package:mcp_server/mcp_server.dart';
import 'package:path/path.dart' as p;

/// Tool for creating and repairing Flutter projects
///
/// Responsibilities:
/// - Creates new Flutter projects with clean architecture
/// - Generates feature-based folder structure
/// - Configures Android flavors (dev/prod)
/// - Repairs projects with flutter clean & pub get
/// - Supports deep clean for stubborn problems
class ProjectCreationTool {
  final Server server;
  final ServerConfig config;

  ProjectCreationTool(this.server, this.config);

  /// Registers both tools with the MCP server
  ///
  /// - create_flutter_project: Create new project
  /// - fix_flutter_project: Repair existing project
  void register() {
    _registerCreateTool();
    _registerFixTool();
  }

  /// Registers the tool for creating new Flutter projects.
  ///
  /// Features:
  /// - Clean architecture with feature folders.
  /// - Riverpod state management.
  /// - Android flavors (dev/prod).
  /// - Optional additional dependencies.
  void _registerCreateTool() {
    server.addTool(
      name: 'create_flutter_project',
      description: 'Create a Flutter project with Clean Architecture',
      inputSchema: {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Project name (snake_case)',
          },
          'organization': {
            'type': 'string',
            'description': 'Organization (e.g., com.company.app)',
          },
          'additional_dependencies': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Additional pub packages',
          },
        },
        'required': ['name'],
      },
      handler: (args) async {
        final name = args['name'] as String;

        final organization =
            args['organization'] as String? ?? 'com.example.app';

        final additionalDeps =
            (args['additional_dependencies'] as List?)?.cast<String>() ??
            <String>[];

        final projectPath = p.join(config.projectsDir, name);

        try {
          if (Directory(projectPath).existsSync()) {
            return CallToolResult(
              content: [
                TextContent(
                  text: 'Error: Project "$name" already exists at $projectPath',
                ),
              ],
              isError: true,
            );
          }

          await _createProjectStructure(
            projectPath,
            name,
            organization,
            additionalDeps,
          );

          await FlutterService.runCommandSilent('flutter', [
            'pub',
            'get',
          ], projectPath);

          return CallToolResult(
            content: [
              TextContent(
                text:
                    '''
✅ Flutter project "$name" created successfully!

📍 Location: $projectPath
🏗️  Architecture: Feature-based Clean Architecture
⚡ State Management: Riverpod (AsyncNotifier)
🎨 Build Variants:
   • Android: dev & prod flavors (--flavor)
   • Web: environment via --dart-define

Next steps:
- Use run_flutter_web to start on Chrome (--dart-define=ENVIRONMENT=dev/prod)
- Use run_flutter_android to start on emulator (--flavor dev/prod)
''',
              ),
            ],
          );
        } catch (e) {
          return CallToolResult(
            content: [TextContent(text: 'Error creating project: $e')],
            isError: true,
          );
        }
      },
    );
  }

  /// Registers the tool for repairing existing projects.
  ///
  /// Use cases:
  /// - Resolve dependency issues.
  /// - Clean up build artifacts.
  /// - Resolve conflicts after Git merges.
  /// - Eliminate cache issues (deep_clean).
  void _registerFixTool() {
    server.addTool(
      name: 'fix_flutter_project',
      description: 'Fix Flutter project issues',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {
            'type': 'string',
            'description': 'Project name or absolute path',
          },
          'deep_clean': {
            'type': 'boolean',
            'description': 'Perform deep clean',
            'default': false,
          },
        },
        'required': ['path'],
      },
      handler: (args) async {
        final path = PathService.resolvePath(
          args['path'] as String,
          config.projectsDir,
        );

        final deepClean = args['deep_clean'] as bool? ?? false;

        if (!Directory(path).existsSync()) {
          return CallToolResult(
            content: [TextContent(text: 'Error: Project not found at $path')],
            isError: true,
          );
        }

        try {
          if (deepClean) {
            await FlutterService.deepClean(path);
          }

          await FlutterService.runCommandSilent('flutter', ['clean'], path);

          await FlutterService.runCommandSilent('flutter', [
            'pub',
            'get',
          ], path);

          return CallToolResult(
            content: [
              TextContent(
                text: '✅ Flutter project fixed successfully at $path',
              ),
            ],
          );
        } catch (e) {
          return CallToolResult(
            content: [TextContent(text: 'Error fixing project: $e')],
            isError: true,
          );
        }
      },
    );
  }

  Future<void> _createProjectStructure(
    String projectPath,
    String name,
    String organization,
    List<String> additionalDeps,
  ) async {
    final dirs = [
      'lib/app/core',
      'lib/app/config',
      'lib/app/providers',
      'lib/features/feature_template/application/use_case',
      'lib/features/feature_template/data/repository',
      'lib/features/feature_template/domain/entity',
      'lib/features/feature_template/domain/repositories',
      'lib/features/feature_template/presentation/notifier',
      'lib/features/feature_template/presentation/providers',
      'lib/features/feature_template/presentation/screens',
      'lib/features/feature_template/presentation/widgets',
      'lib/features/feature_template/presentation/state',
    ];

    for (final dir in dirs) {
      await Directory(p.join(projectPath, dir)).create(recursive: true);
    }

    await File(
      p.join(projectPath, 'pubspec.yaml'),
    ).writeAsString(PubspecTemplate.generate(name, additionalDeps));

    await File(
      p.join(projectPath, 'lib/main.dart'),
    ).writeAsString(MainTemplate.generate(name));

    final androidDir = Directory(p.join(projectPath, 'android', 'app'));
    if (!androidDir.existsSync()) {
      await androidDir.create(recursive: true);
    }
    await File(
      p.join(projectPath, 'android', 'app', 'build.gradle'),
    ).writeAsString(GradleTemplate.generate(organization));

    await File(
      p.join(projectPath, '.env.dev'),
    ).writeAsString('# Development\n');

    await File(
      p.join(projectPath, '.env.prod'),
    ).writeAsString('# Production\n');

    await File(p.join(projectPath, '.gitignore')).writeAsString('''
.dart_tool/          # Dart SDK Tools Cache
.packages            # Package Dependencies (veraltet)
build/               # Build Output
.env                 # Environment Variables (Secrets!)
.flutter-plugins     # Flutter Plugin Registry
.flutter-plugins-dependencies
pubspec.lock         # Dependency Versions (sollte committed werden bei Apps)
''');
  }
}
