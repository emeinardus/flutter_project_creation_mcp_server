import 'package:flutter_mcp_server/services/path_services.dart';
import 'package:mcp_server/mcp_server.dart';
import '../config/server_config.dart';
import '../services/project_analyzer.dart';
import 'dart:io';

/// Intelligent tool for project analysis
///
/// Collects complete project context and returns it,
/// so that AI can:
/// - Diagnose errors
/// - Suggest specific fixes
/// - Debug iteratively
class ProjectAnalysisTool {
  final Server server;
  final ServerConfig config;

  ProjectAnalysisTool(this.server, this.config);

  void register() {
    _registerAnalyzeTool();
    _registerValidateTool();
  }

  /// Tool: Analyze Flutter project completely
  ///
  /// AI receives:
  /// - Project structure
  /// - Dependencies (pubspec.yaml, pubspec.lock)
  /// - Configuration (build.gradle, etc.)
  /// - Errors & warnings
  /// - Flutter environment information
  void _registerAnalyzeTool() {
    server.addTool(
      name: 'analyze_flutter_project',
      description: '''
Deeply analyze a Flutter project and return comprehensive information.

This tool provides:
- Project structure (folders, files, features)
- Dependencies (pubspec.yaml, pubspec.lock)
- Configuration files (build.gradle, AndroidManifest.xml)
- Current errors and warnings
- Flutter environment details

Use this when:
- User reports errors or issues
- Need to understand project state
- Before suggesting fixes
- To validate project health

AFTER ANALYZING:
→ Immediately call: apply_code_fix or apply_batch_fixes
→ Then call: validate_flutter_project to check if fixes worked
''',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {
            'type': 'string',
            'description': 'Project name or absolute path',
          },
          'include_code_samples': {
            'type': 'boolean',
            'description': 'Include code samples from key files',
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

        if (!Directory(path).existsSync()) {
          return CallToolResult(
            content: [TextContent(text: 'Error: Project not found at $path')],
            isError: true,
          );
        }

        server.sendLog(McpLogLevel.info, 'Analyzing project: $path');

        try {
          final analysis = await ProjectAnalyzer.analyzeProject(path);

          final formattedAnalysis = ProjectAnalyzer.formatForClaude(analysis);

          server.sendLog(McpLogLevel.info, 'Analysis complete');

          return CallToolResult(
            content: [TextContent(text: formattedAnalysis)],
          );
        } catch (e) {
          return CallToolResult(
            content: [TextContent(text: 'Error analyzing project: $e')],
            isError: true,
          );
        }
      },
    );
  }

  /// Tool: Validate whether project is functional
  ///
  /// Performs tests:
  /// - flutter pub get successful?
  /// - flutter analyze without errors?
  /// - Can be compiled?
  void _registerValidateTool() {
    server.addTool(
      name: 'validate_flutter_project',
      description: '''
Validate that a Flutter project is in working condition.

Runs:
1. flutter pub get
2. flutter analyze
3. Optional: flutter build (dry-run)

Returns success/failure with detailed error messages.
Use this after applying fixes to verify they worked.

IF THIS TOOL FAILS:
→ Immediately call: analyze_flutter_project(path: same_path)
→ Then call: apply_code_fix or apply_batch_fixes  
→ Then call: validate_flutter_project (this tool again)
→ Repeat until success (max 3 times)
''',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {
            'type': 'string',
            'description': 'Project name or absolute path',
          },
          'run_build_check': {
            'type': 'boolean',
            'description': 'Also check if project can build',
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
        final runBuildCheck = args['run_build_check'] as bool? ?? false;

        if (!Directory(path).existsSync()) {
          return CallToolResult(
            content: [TextContent(text: 'Error: Project not found at $path')],
            isError: true,
          );
        }

        final results = <String>[];
        var allPassed = true;

        server.sendLog(McpLogLevel.info, 'Running: flutter pub get');
        final pubGetResult = await Process.run('flutter', [
          'pub',
          'get',
        ], workingDirectory: path);

        if (pubGetResult.exitCode == 0) {
          results.add('✅ flutter pub get: PASSED');
        } else {
          results.add('❌ flutter pub get: FAILED');
          results.add('Error: ${pubGetResult.stderr}');
          allPassed = false;
        }

        server.sendLog(McpLogLevel.info, 'Running: flutter analyze');
        final analyzeResult = await Process.run('flutter', [
          'analyze',
        ], workingDirectory: path);

        if (analyzeResult.exitCode == 0) {
          results.add('✅ flutter analyze: PASSED');
        } else {
          results.add('❌ flutter analyze: FAILED');
          results.add('Output: ${analyzeResult.stdout}');
          allPassed = false;
        }

        if (runBuildCheck) {
          server.sendLog(
            McpLogLevel.info,
            'Running: flutter build apk --debug',
          );
          final buildResult = await Process.run('flutter', [
            'build',
            'apk',
            '--debug',
          ], workingDirectory: path);

          if (buildResult.exitCode == 0) {
            results.add('✅ flutter build: PASSED');
          } else {
            results.add('❌ flutter build: FAILED');
            results.add('Error: ${buildResult.stderr}');
            allPassed = false;
          }
        }

        final summary = allPassed
            ? '\n🎉 All validation tests passed! Project is healthy.'
            : '\n⚠️ Some tests failed. See details above.';

        return CallToolResult(
          content: [
            TextContent(
              text:
                  '''
# VALIDATION RESULTS

${results.join('\n')}

$summary
''',
            ),
          ],
        );
      },
    );
  }
}
