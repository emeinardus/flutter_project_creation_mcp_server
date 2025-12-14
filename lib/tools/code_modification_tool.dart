import 'dart:io';
import 'package:flutter_mcp_server/services/path_services.dart';
import 'package:mcp_server/mcp_server.dart';
import 'package:path/path.dart' as p;
import '../config/server_config.dart';

/// Tool for intelligent code modifications
///
/// Allows to:
/// - Edit files based on analysis
/// - Apply multiple fixes at once
/// - Validate changes
class CodeModificationTool {
  final Server server;
  final ServerConfig config;

  CodeModificationTool(this.server, this.config);

  void register() {
    _registerApplyFixTool();
    _registerBatchFixTool();
    _registerReadFileTool();
  }

  void _registerApplyFixTool() {
    server.addTool(
      name: 'apply_code_fix',
      description: '''
Apply a specific code fix to a Flutter project file.

Use this to:
- Fix dependency conflicts in pubspec.yaml
- Update Gradle configurations
- Modify source code files
- Create missing files

After applying, the tool automatically validates the change.

AFTER APPLYING FIX:
→ Immediately call: validate_flutter_project
→ If still failing: analyze_flutter_project again
''',
      inputSchema: {
        'type': 'object',
        'properties': {
          'project_path': {
            'type': 'string',
            'description': 'Project name or absolute path',
          },
          'file_path': {
            'type': 'string',
            'description':
                'Relative path to file from project root (e.g., "pubspec.yaml", "android/app/build.gradle")',
          },
          'content': {
            'type': 'string',
            'description': 'New complete file content',
          },
          'description': {
            'type': 'string',
            'description': 'Human-readable description of what this fix does',
          },
          'validate_after': {
            'type': 'boolean',
            'description': 'Run pub get after applying fix',
            'default': true,
          },
        },
        'required': ['project_path', 'file_path', 'content', 'description'],
      },
      handler: (args) async {
        final projectPath = PathService.resolvePath(
          args['project_path'] as String,
          config.projectsDir,
        );
        final filePath = args['file_path'] as String;
        final content = args['content'] as String;
        final description = args['description'] as String;
        final validateAfter = args['validate_after'] as bool? ?? true;

        if (!Directory(projectPath).existsSync()) {
          return CallToolResult(
            content: [
              TextContent(text: 'Error: Project not found at $projectPath'),
            ],
            isError: true,
          );
        }

        server.sendLog(McpLogLevel.info, 'Applying fix: $description');

        try {
          final targetFile = File(p.join(projectPath, filePath));
          String? backup;
          if (await targetFile.exists()) {
            backup = await targetFile.readAsString();
            server.sendLog(McpLogLevel.info, 'Backed up original file');
          }

          await targetFile.writeAsString(content);
          server.sendLog(McpLogLevel.info, 'File updated: $filePath');

          String validationResult = '';
          if (validateAfter) {
            server.sendLog(McpLogLevel.info, 'Validating change...');

            final pubGetResult = await Process.run('flutter', [
              'pub',
              'get',
            ], workingDirectory: projectPath);

            if (pubGetResult.exitCode == 0) {
              validationResult = '\n✅ Validation: pub get succeeded';
            } else {
              validationResult =
                  '\n❌ Validation: pub get failed\n${pubGetResult.stderr}';

              if (backup != null) {
                await targetFile.writeAsString(backup);
                server.sendLog(
                  McpLogLevel.warning,
                  'Rolled back changes due to validation failure',
                );

                return CallToolResult(
                  content: [
                    TextContent(
                      text:
                          '''
❌ Fix failed validation and was rolled back.

Description: $description
File: $filePath

Error:
${pubGetResult.stderr}

Please revise the fix and try again.
''',
                    ),
                  ],
                  isError: true,
                );
              }
            }
          }

          return CallToolResult(
            content: [
              TextContent(
                text:
                    '''
✅ Fix applied successfully!

Description: $description
File: $filePath
$validationResult

You can now run validate_flutter_project to do a full check,
or apply additional fixes if needed.
''',
              ),
            ],
          );
        } catch (e) {
          return CallToolResult(
            content: [TextContent(text: 'Error applying fix: $e')],
            isError: true,
          );
        }
      },
    );
  }

  void _registerBatchFixTool() {
    server.addTool(
      name: 'apply_batch_fixes',
      description: '''
Apply multiple code fixes at once in a single transaction.

Use this when a problem requires changes to multiple files.
All changes are applied together, and if validation fails,
all changes are rolled back.
''',
      inputSchema: {
        'type': 'object',
        'properties': {
          'project_path': {
            'type': 'string',
            'description': 'Project name or absolute path',
          },
          'fixes': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'file_path': {'type': 'string'},
                'content': {'type': 'string'},
                'description': {'type': 'string'},
              },
              'required': ['file_path', 'content', 'description'],
            },
            'description': 'Array of fixes to apply',
          },
        },
        'required': ['project_path', 'fixes'],
      },
      handler: (args) async {
        final projectPath = PathService.resolvePath(
          args['project_path'] as String,
          config.projectsDir,
        );
        final fixes = args['fixes'] as List;

        if (!Directory(projectPath).existsSync()) {
          return CallToolResult(
            content: [
              TextContent(text: 'Error: Project not found at $projectPath'),
            ],
            isError: true,
          );
        }

        server.sendLog(McpLogLevel.info, 'Applying ${fixes.length} fixes...');

        final backups = <String, String>{};

        try {
          for (final fix in fixes) {
            final filePath = fix['file_path'] as String;
            final targetFile = File(p.join(projectPath, filePath));

            if (await targetFile.exists()) {
              backups[filePath] = await targetFile.readAsString();
            }
          }

          final appliedFixes = <String>[];
          for (final fix in fixes) {
            final filePath = fix['file_path'] as String;
            final content = fix['content'] as String;
            final description = fix['description'] as String;

            final targetFile = File(p.join(projectPath, filePath));
            await targetFile.writeAsString(content);

            appliedFixes.add('• $filePath: $description');
            server.sendLog(McpLogLevel.info, 'Applied: $description');
          }

          server.sendLog(McpLogLevel.info, 'Validating batch fixes...');
          final pubGetResult = await Process.run('flutter', [
            'pub',
            'get',
          ], workingDirectory: projectPath);

          if (pubGetResult.exitCode != 0) {
            server.sendLog(
              McpLogLevel.warning,
              'Validation failed, rolling back...',
            );

            for (final entry in backups.entries) {
              final targetFile = File(p.join(projectPath, entry.key));
              await targetFile.writeAsString(entry.value);
            }

            return CallToolResult(
              content: [
                TextContent(
                  text:
                      '''
❌ Batch fixes failed validation and were rolled back.

Applied fixes:
${appliedFixes.join('\n')}

Error:
${pubGetResult.stderr}

Please revise the fixes and try again.
''',
                ),
              ],
              isError: true,
            );
          }

          return CallToolResult(
            content: [
              TextContent(
                text:
                    '''
✅ All ${fixes.length} fixes applied successfully!

Changes:
${appliedFixes.join('\n')}

✅ Validation: pub get succeeded

Project is ready. You can now run validate_flutter_project for a full check.
''',
              ),
            ],
          );
        } catch (e) {
          for (final entry in backups.entries) {
            final targetFile = File(p.join(projectPath, entry.key));
            await targetFile.writeAsString(entry.value);
          }

          return CallToolResult(
            content: [TextContent(text: 'Error applying batch fixes: $e')],
            isError: true,
          );
        }
      },
    );
  }

  void _registerReadFileTool() {
    server.addTool(
      name: 'read_project_file',
      description: '''
Read the content of a specific file in the Flutter project.

Use this when you need to:
- Examine a file in detail before suggesting a fix
- Read code to understand the implementation
- Check configuration files

Note: analyze_flutter_project already includes most common files,
so only use this for additional files not in the analysis.
''',
      inputSchema: {
        'type': 'object',
        'properties': {
          'project_path': {
            'type': 'string',
            'description': 'Project name or absolute path',
          },
          'file_path': {
            'type': 'string',
            'description': 'Relative path to file from project root',
          },
        },
        'required': ['project_path', 'file_path'],
      },
      handler: (args) async {
        final projectPath = PathService.resolvePath(
          args['project_path'] as String,
          config.projectsDir,
        );
        final filePath = args['file_path'] as String;

        if (!Directory(projectPath).existsSync()) {
          return CallToolResult(
            content: [
              TextContent(text: 'Error: Project not found at $projectPath'),
            ],
            isError: true,
          );
        }

        try {
          final targetFile = File(p.join(projectPath, filePath));

          if (!await targetFile.exists()) {
            return CallToolResult(
              content: [TextContent(text: 'Error: File not found: $filePath')],
              isError: true,
            );
          }

          final content = await targetFile.readAsString();

          return CallToolResult(
            content: [
              TextContent(
                text:
                    '''
File: $filePath
```
$content
```
''',
              ),
            ],
          );
        } catch (e) {
          return CallToolResult(
            content: [TextContent(text: 'Error reading file: $e')],
            isError: true,
          );
        }
      },
    );
  }
}
