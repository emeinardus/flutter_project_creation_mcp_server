import 'dart:io';
import 'package:path/path.dart' as p;

class PathService {
  static String getProjectsDirectory() {
    // 1. Desktop (bevorzugt)
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final desktop = p.join(userProfile, 'Desktop');
        if (Directory(desktop).existsSync()) {
          return desktop;
        }
      }
    } else if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        final desktop = p.join(home, 'Desktop');
        if (Directory(desktop).existsSync()) {
          return desktop;
        }
      }
    }

    // 2. Documents als Fallback
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final documents = p.join(userProfile, 'Documents');
        if (Directory(documents).existsSync()) {
          return documents;
        }
      }
    } else if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        final documents = p.join(home, 'Documents');
        if (Directory(documents).existsSync()) {
          return documents;
        }
      }
    }

    // 3. Home als letzter Fallback
    if (Platform.isWindows) {
      return Platform.environment['USERPROFILE'] ?? Directory.current.path;
    } else {
      return Platform.environment['HOME'] ?? Directory.current.path;
    }
  }

  static String resolvePath(String path, String projectsDir) {
    if (!path.contains(Platform.pathSeparator)) {
      return p.join(projectsDir, path);
    }
    return path;
  }
}
