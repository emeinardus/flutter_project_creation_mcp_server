import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter_mcp_server/config/server_config.dart';
import 'package:flutter_mcp_server/services/emulator_service.dart';
import 'package:flutter_mcp_server/services/flutter_service.dart';
import 'package:flutter_mcp_server/services/path_services.dart';
import 'package:mcp_server/mcp_server.dart';

/// Tool to run the created Flutter Project on an Android-Emulator
///
/// Responsibilities:
/// - Registers the `run_flutter_android` MCP tool
/// - Automatically launches Android emulators when necessary
/// - Runs Flutter apps with flavor support (dev/prod)
/// - Monitors the Flutter process and logs status messages
class AndroidTool {
  final Server server;
  final ServerConfig config;

  AndroidTool(this.server, this.config);

  void register() {
    server.addTool(
      name: 'run_flutter_android',
      description:
          'Run Flutter project on Android emulator with flavor support',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {
            'type': 'string',
            'description': 'Project name or absolute path',
          },
          'flavor': {
            'type': 'string',
            'enum': ['dev', 'prod'],
            'description': 'Build flavor (Android native flavor)',
            'default': 'dev',
          },
          'emulator': {
            'type': 'string',
            'description':
                'Emulator name (optional, uses first available if not specified)',
          },
        },
        'required': ['path'],
      },
      handler: (args) async {
        final path = PathService.resolvePath(
          args['path'] as String,
          config.projectsDir,
        );

        final flavor = args['flavor'] as String? ?? 'dev';

        final emulatorName = args['emulator'] as String?;

        if (!Directory(path).existsSync()) {
          return CallToolResult(
            content: [TextContent(text: 'Error: Project not found at $path')],
            isError: true,
          );
        }

        final emulatorResult = await _ensureEmulatorRunning(emulatorName);
        if (emulatorResult != null) {
          return emulatorResult;
        }

        await FlutterService.runCommandSilent('flutter', ['pub', 'get'], path);

        _startFlutterAndroid(path, flavor);

        return CallToolResult(
          content: [
            TextContent(
              text:
                  '''
📱 Flutter Android (flavor: $flavor) is starting...

📍 Project: $path
🎨 Flavor: $flavor (native Android flavor via --flavor)
🚀 App will launch on emulator in ~10-30 seconds

The server will remain connected. Use shutdown_server to close.
''',
            ),
          ],
        );
      },
    );
  }

  /// Ensures that an Android emulator is running.
  ///
  /// Procedure:
  /// 1. Checks whether an emulator is already running.
  /// 2. If not: Lists available emulators.
  /// 3. Starts the desired (or first) emulator.
  /// 4. Wait until the emulator has booted completely.
  ///
  /// Returns:
  /// - `null` if successful.
  /// - `CallToolResult` with an error if something goes wrong.
  Future<CallToolResult?> _ensureEmulatorRunning(String? emulatorName) async {
    final runningDevices = await FlutterService.getRunningDevices();

    if (!runningDevices.any((d) => d.contains('emulator'))) {
      server.sendLog(McpLogLevel.info, 'No emulator running, starting one...');

      final emulators = await EmulatorService.listEmulators();

      if (emulators.isEmpty) {
        return CallToolResult(
          content: [
            TextContent(
              text: '''
❌ No Android emulators found!

Please create an emulator first:
- Open Android Studio
- Tools → Device Manager → Create Device

Or use command line:
avdmanager create avd -n MyEmulator -k "system-images;android-34;google_apis;x86_64"
''',
            ),
          ],
          isError: true,
        );
      }

      final targetEmulator = emulatorName ?? emulators.first;

      if (!emulators.contains(targetEmulator)) {
        return CallToolResult(
          content: [
            TextContent(
              text:
                  '''
❌ Emulator "$targetEmulator" not found!

Available emulators:
${emulators.map((e) => '• $e').join('\n')}
''',
            ),
          ],
          isError: true,
        );
      }

      server.sendLog(McpLogLevel.info, 'Starting emulator: $targetEmulator');

      try {
        await EmulatorService.startEmulator(targetEmulator);

        server.sendLog(
          McpLogLevel.info,
          'Emulator started, waiting for boot...',
        );

        await EmulatorService.waitForBoot();

        server.sendLog(McpLogLevel.info, 'Emulator is ready!');
      } catch (e) {
        return CallToolResult(
          content: [TextContent(text: 'Error starting emulator: $e')],
          isError: true,
        );
      }
    }

    return null;
  }

  /// Starts the Flutter Android app in the background.
  ///
  /// Process is started detached so that:
  /// - The MCP server is not blocked.
  /// - The app continues to run even when the tool returns.
  /// - Logs can be streamed in real time.
  ///
  /// Args:
  /// - path: Absolute path to the Flutter project
  /// - flavor: Build flavor (dev or prod)
  void _startFlutterAndroid(String path, String flavor) {
    final args = [
      'run'
          '--flavor',
      flavor,
      '--dart-define=ENVIRONMENT=$flavor',
    ];

    Process.start('flutter', args, workingDirectory: path, runInShell: true)
        .then((process) {
          server.sendLog(
            McpLogLevel.info,
            'Flutter Android process started (flavor: $flavor)',
          );

          process.stdout
              .transform(utf8.decoder)
              .transform(LineSplitter())
              .listen((line) {
                if (line.contains('Flutter run key commands') ||
                    line.contains('Running with sound null safety')) {
                  server.sendLog(
                    McpLogLevel.info,
                    '✓ Flutter Android app is running!',
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
          server.sendLog(
            McpLogLevel.error,
            'Failed to start Flutter Android: $e',
          );
        });
  }
}
