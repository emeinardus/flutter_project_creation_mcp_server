import 'dart:io';
import 'dart:convert';
import 'package:flutter_mcp_server/config/server_config.dart';
import 'package:flutter_mcp_server/services/flutter_service.dart';
import 'package:flutter_mcp_server/services/path_services.dart';
import 'package:mcp_server/mcp_server.dart';

class WebTool {
  final Server server;
  final ServerConfig config;

  WebTool(this.server, this.config);

  void register() {
    server.addTool(
      name: 'run_flutter_web',
      description:
          'Run Flutter project on Chrome with environment variable (Web does not support flavors)',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {
            'type': 'string',
            'description': 'Project name or absolute path',
          },
          'environment': {
            'type': 'string',
            'enum': ['dev', 'prod'],
            'description':
                'Environment variable (passed as --dart-define=ENVIRONMENT=...)',
            'default': 'dev',
          },
        },
        'required': ['path'],
      },
      handler: (args) async {
        final path = PathService.resolvePath(
          args['path'] as String,
          config.projectsDir,
        );
        final environment = args['environment'] as String? ?? 'dev';

        if (!Directory(path).existsSync()) {
          return CallToolResult(
            content: [TextContent(text: 'Error: Project not found at $path')],
            isError: true,
          );
        }

        await FlutterService.runCommandSilent('flutter', ['pub', 'get'], path);

        _startFlutterWeb(path, environment);

        return CallToolResult(
          content: [
            TextContent(
              text:
                  '''
🌐 Flutter Web (environment: $environment) is starting...

📍 Project: $path
🎯 Environment: $environment (via --dart-define=ENVIRONMENT=$environment)
🚀 Chrome will open in ~10-30 seconds

Note: Web doesn't support native flavors, only dart-define variables.

The server will remain connected. Use shutdown_server to close.
''',
            ),
          ],
        );
      },
    );
  }

  void _startFlutterWeb(String path, String environment) {
    final args = [
      'run',
      '-d',
      'chrome',
      '--dart-define=ENVIRONMENT=$environment',
    ];

    Process.start('flutter', args, workingDirectory: path, runInShell: true)
        .then((process) {
          server.sendLog(
            McpLogLevel.info,
            'Flutter Web process started (environment: $environment)',
          );

          process.stdout
              .transform(utf8.decoder)
              .transform(LineSplitter())
              .listen((line) {
                if (line.contains('Flutter run key commands') ||
                    line.contains('Running with sound null safety')) {
                  server.sendLog(
                    McpLogLevel.info,
                    '✓ Flutter Web app is running!',
                  );
                }
              });

          process.stderr
              .transform(utf8.decoder)
              .transform(LineSplitter())
              .listen((line) {
                if (line.toLowerCase().contains('error') &&
                    !line.contains('DevTools')) {
                  server.sendLog(McpLogLevel.error, line);
                }
              });
        })
        .catchError((e) {
          server.sendLog(McpLogLevel.error, 'Failed to start Flutter Web: $e');
        });
  }
}
