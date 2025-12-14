import 'dart:io';
import 'package:mcp_server/mcp_server.dart';
import '../config/server_config.dart';
import '../services/flutter_service.dart';
import '../services/emulator_service.dart';

class ServerInfoTool {
  final Server server;
  final ServerConfig config;

  ServerInfoTool(this.server, this.config);

  void register() {
    _registerShutdownTool();
    _registerInfoTool();
    _registerListEmulatorsTool();
  }

  void _registerShutdownTool() {
    server.addTool(
      name: 'shutdown_server',
      description: 'Shutdown the Flutter MCP Server gracefully',
      inputSchema: {
        'type': 'object',
        'properties': {
          'confirm': {
            'type': 'boolean',
            'description': 'Confirm shutdown (must be true)',
            'default': true,
          },
        },
      },
      handler: (args) async {
        final confirm = args['confirm'] as bool? ?? true;

        if (!confirm) {
          return CallToolResult(
            content: [TextContent(text: 'Shutdown cancelled.')],
          );
        }

        server.sendLog(McpLogLevel.info, 'Shutdown requested by user');
        config.requestShutdown();

        return CallToolResult(
          content: [
            TextContent(text: '✅ MCP Server is shutting down...\nGoodbye! 👋'),
          ],
        );
      },
    );
  }

  void _registerInfoTool() {
    server.addTool(
      name: 'get_server_info',
      description: 'Get information about the MCP server configuration',
      inputSchema: {'type': 'object', 'properties': {}},
      handler: (args) async {
        final flutterVersion = await FlutterService.getVersion();
        final emulators = await EmulatorService.listEmulators();

        return CallToolResult(
          content: [
            TextContent(
              text:
                  '''
📋 Flutter MCP Server Info:

Projects Directory: ${config.projectsDir}
Flutter Version: $flutterVersion
Operating System: ${Platform.operatingSystem}
Available Emulators: ${emulators.isEmpty ? 'None' : emulators.join(', ')}
Server Version: ${config.version}

Available Commands:
- Create projects with Clean Architecture
- Run projects on Web (Chrome) - uses --dart-define
- Run projects on Android - uses --flavor
- Fix project issues
- Shutdown server

Note: Web doesn't support native flavors, only dart-define variables.

Use shutdown_server tool to close this server.
''',
            ),
          ],
        );
      },
    );
  }

  void _registerListEmulatorsTool() {
    server.addTool(
      name: 'list_emulators',
      description: 'List available Android emulators',
      inputSchema: {'type': 'object', 'properties': {}},
      handler: (args) async {
        try {
          final emulators = await EmulatorService.listEmulators();

          if (emulators.isEmpty) {
            return CallToolResult(
              content: [
                TextContent(
                  text: '''
❌ No Android emulators found.

Create one with Android Studio:
Tools → Device Manager → Create Device

Or via command line:
avdmanager create avd -n MyEmulator -k "system-images;android-34;google_apis;x86_64"
''',
                ),
              ],
            );
          }

          return CallToolResult(
            content: [
              TextContent(
                text:
                    '''
📱 Available Android Emulators:

${emulators.map((e) => '• $e').join('\n')}

Use run_flutter_android with emulator parameter to specify which one to use.
''',
              ),
            ],
          );
        } catch (e) {
          return CallToolResult(
            content: [TextContent(text: 'Error listing emulators: $e')],
            isError: true,
          );
        }
      },
    );
  }
}
