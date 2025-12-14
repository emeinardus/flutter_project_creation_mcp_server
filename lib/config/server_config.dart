import 'package:flutter_mcp_server/services/path_services.dart';

class ServerConfig {
  ServerConfig();

  // Server Settings
  final String name = 'flutter-architect-mcp';
  final String version = '1.0.0';
  final bool debugLogging = true;

  // Runtime State
  bool shouldShutdown = false;

  // Paths
  late final String projectsDir = PathService.getProjectsDirectory();

  void requestShutdown() {
    shouldShutdown = true;
  }
}
