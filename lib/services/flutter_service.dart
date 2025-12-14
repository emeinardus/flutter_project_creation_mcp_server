import 'dart:io';

class FlutterService {
  static Future<String> getVersion() async {
    try {
      final result = await Process.run('flutter', ['--version']);
      final output = result.stdout.toString();
      final firstLine = output.split('\n').first;
      return firstLine.trim();
    } catch (e) {
      return 'Unknown (flutter not found in PATH)';
    }
  }

  static Future<void> runCommandSilent(
    String command,
    List<String> args,
    String workingDirectory,
  ) async {
    final process = await Process.start(
      command,
      args,
      workingDirectory: workingDirectory,
      runInShell: true,
    );

    await process.stdout.drain();
    await process.stderr.drain();

    final exitCode = await process.exitCode;

    if (exitCode != 0) {
      throw Exception(
        'Command failed: $command ${args.join(' ')} (exit code: $exitCode)',
      );
    }
  }

  static Future<void> deepClean(String projectPath) async {
    final dirsToDelete = [
      '.dart_tool',
      'build',
      'android/.gradle',
      'android/app/build',
      'ios/.symlinks',
      'ios/Pods',
    ];

    for (final dir in dirsToDelete) {
      final directory = Directory('$projectPath/$dir');
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    }

    final filesToDelete = ['pubspec.lock'];
    for (final file in filesToDelete) {
      final f = File('$projectPath/$file');
      if (f.existsSync()) {
        await f.delete();
      }
    }
  }

  static Future<List<String>> getRunningDevices() async {
    try {
      final result = await Process.run('flutter', ['devices']);
      return result.stdout.toString().split('\n');
    } catch (e) {
      return [];
    }
  }
}
