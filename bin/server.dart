import 'dart:io';
import 'package:flutter_mcp_server/tools/project_creation_tool.dart';
import 'package:mcp_server/mcp_server.dart';
import 'package:flutter_mcp_server/config/server_config.dart';
import 'package:flutter_mcp_server/tools/server_info_tool.dart';
import 'package:flutter_mcp_server/tools/project_analysis_tool.dart';
import 'package:flutter_mcp_server/tools/code_modification_tool.dart';
import 'package:flutter_mcp_server/tools/web_tool.dart';
import 'package:flutter_mcp_server/tools/android_tool.dart';

void main(List<String> args) async {
  final config = ServerConfig();

  await McpServer.createAndStart(
    config: McpServer.simpleConfig(
      name: config.name,
      version: config.version,
      enableDebugLogging: config.debugLogging,
    ),
    transportConfig: TransportConfig.stdio(),
  ).then((result) async {
    await result.fold(
      (server) async {
        _registerTools(server, config);
        _startServer(server, config);

        while (!config.shouldShutdown) {
          await Future.delayed(const Duration(seconds: 1));
        }

        server.sendLog(McpLogLevel.info, 'Shutting down MCP Server...');
        exit(0);
      },
      (error) {
        stderr.writeln('Failed to start MCP server: $error');
        exit(1);
      },
    );
  });
}

void _registerTools(Server server, ServerConfig config) {
  ServerInfoTool(server, config).register();

  ProjectCreationTool(server, config).register();

  ProjectAnalysisTool(server, config).register();
  CodeModificationTool(server, config).register();

  WebTool(server, config).register();
  AndroidTool(server, config).register();
}

void _startServer(Server server, ServerConfig config) {
  server.sendLog(McpLogLevel.info, '🤖 Agentic Flutter MCP Server started');
  server.sendLog(McpLogLevel.info, 'Projects directory: ${config.projectsDir}');
  server.sendLog(McpLogLevel.info, 'OS: ${Platform.operatingSystem}');
  server.sendLog(McpLogLevel.info, '\nIntelligent Tools Available:');
  server.sendLog(
    McpLogLevel.info,
    '  • analyze_flutter_project - Deep project analysis',
  );
  server.sendLog(
    McpLogLevel.info,
    '  • apply_code_fix - Apply AI-suggested fixes',
  );
  server.sendLog(
    McpLogLevel.info,
    '  • validate_flutter_project - Verify fixes worked',
  );
}
