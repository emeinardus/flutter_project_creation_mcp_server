import 'dart:io';
import 'package:path/path.dart' as p;

/// Service zum Analysieren von Flutter-Projekten
///
/// Sammelt alle relevanten Informationen die Claude braucht um:
/// - Fehler zu diagnostizieren
/// - Code-Qualität zu bewerten
/// - Fixes vorzuschlagen
class ProjectAnalyzer {
  /// Analysiert ein Flutter-Projekt vollständig
  ///
  /// Returns: Map mit allen relevanten Projekt-Infos
  static Future<Map<String, dynamic>> analyzeProject(String projectPath) async {
    final analysis = <String, dynamic>{};

    // 1. Projekt-Struktur
    analysis['structure'] = await _analyzeStructure(projectPath);

    // 2. Dependencies
    analysis['dependencies'] = await _analyzeDependencies(projectPath);

    // 3. Konfiguration
    analysis['configuration'] = await _analyzeConfiguration(projectPath);

    // 4. Fehler & Warnungen
    analysis['issues'] = await _findIssues(projectPath);

    // 5. Flutter Environment
    analysis['flutter_info'] = await _getFlutterInfo();

    return analysis;
  }

  /// Analysiert Ordnerstruktur des Projekts
  static Future<Map<String, dynamic>> _analyzeStructure(
    String projectPath,
  ) async {
    final structure = <String, dynamic>{};

    // Prüfe ob wichtige Dateien existieren
    structure['has_pubspec'] = await File(
      p.join(projectPath, 'pubspec.yaml'),
    ).exists();
    structure['has_main'] = await File(
      p.join(projectPath, 'lib/main.dart'),
    ).exists();
    structure['has_android'] = await Directory(
      p.join(projectPath, 'android'),
    ).exists();
    structure['has_ios'] = await Directory(p.join(projectPath, 'ios')).exists();
    structure['has_web'] = await Directory(p.join(projectPath, 'web')).exists();

    // Liste alle Features
    final featuresDir = Directory(p.join(projectPath, 'lib/features'));
    if (await featuresDir.exists()) {
      structure['features'] = await featuresDir
          .list()
          .where((entity) => entity is Directory)
          .map((entity) => p.basename(entity.path))
          .toList();
    } else {
      structure['features'] = [];
    }

    return structure;
  }

  /// Analysiert Dependencies aus pubspec.yaml
  static Future<Map<String, dynamic>> _analyzeDependencies(
    String projectPath,
  ) async {
    final deps = <String, dynamic>{};

    try {
      final pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));
      if (await pubspecFile.exists()) {
        final content = await pubspecFile.readAsString();
        deps['pubspec_content'] = content;

        // Prüfe ob pubspec.lock existiert
        final lockFile = File(p.join(projectPath, 'pubspec.lock'));
        deps['has_lockfile'] = await lockFile.exists();

        if (await lockFile.exists()) {
          deps['lockfile_content'] = await lockFile.readAsString();
        }
      }
    } catch (e) {
      deps['error'] = e.toString();
    }

    return deps;
  }

  /// Analysiert Projekt-Konfiguration (Gradle, etc.)
  static Future<Map<String, dynamic>> _analyzeConfiguration(
    String projectPath,
  ) async {
    final config = <String, dynamic>{};

    // Android Gradle
    final buildGradle = File(p.join(projectPath, 'android/app/build.gradle'));
    if (await buildGradle.exists()) {
      config['android_build_gradle'] = await buildGradle.readAsString();
    }

    // Android Manifest
    final manifest = File(
      p.join(projectPath, 'android/app/src/main/AndroidManifest.xml'),
    );
    if (await manifest.exists()) {
      config['android_manifest'] = await manifest.readAsString();
    }

    // .env Dateien
    final envDev = File(p.join(projectPath, '.env.dev'));
    if (await envDev.exists()) {
      config['has_env_dev'] = true;
    }

    final envProd = File(p.join(projectPath, '.env.prod'));
    if (await envProd.exists()) {
      config['has_env_prod'] = true;
    }

    return config;
  }

  /// Sucht nach Fehlern und Warnungen
  static Future<Map<String, dynamic>> _findIssues(String projectPath) async {
    final issues = <String, dynamic>{};

    // 1. Führe flutter pub get aus und fange Fehler ab
    try {
      final pubGetResult = await Process.run('flutter', [
        'pub',
        'get',
      ], workingDirectory: projectPath);

      issues['pub_get_exit_code'] = pubGetResult.exitCode;
      issues['pub_get_stdout'] = pubGetResult.stdout.toString();
      issues['pub_get_stderr'] = pubGetResult.stderr.toString();
    } catch (e) {
      issues['pub_get_error'] = e.toString();
    }

    // 2. Führe flutter analyze aus
    try {
      final analyzeResult = await Process.run('flutter', [
        'analyze',
      ], workingDirectory: projectPath);

      issues['analyze_exit_code'] = analyzeResult.exitCode;
      issues['analyze_output'] = analyzeResult.stdout.toString();
    } catch (e) {
      issues['analyze_error'] = e.toString();
    }

    // 3. Prüfe auf häufige Probleme
    final dartTool = Directory(p.join(projectPath, '.dart_tool'));
    issues['has_dart_tool'] = await dartTool.exists();

    final buildDir = Directory(p.join(projectPath, 'build'));
    issues['has_build_dir'] = await buildDir.exists();

    return issues;
  }

  /// Holt Flutter Environment Informationen
  static Future<Map<String, dynamic>> _getFlutterInfo() async {
    final info = <String, dynamic>{};

    try {
      // Flutter Version
      final versionResult = await Process.run('flutter', ['--version']);
      info['version'] = versionResult.stdout.toString();

      // Flutter Doctor
      final doctorResult = await Process.run('flutter', ['doctor', '-v']);
      info['doctor'] = doctorResult.stdout.toString();
    } catch (e) {
      info['error'] = e.toString();
    }

    return info;
  }

  /// Formatiert die Analyse für Claude in lesbarem Format
  static String formatForClaude(Map<String, dynamic> analysis) {
    final buffer = StringBuffer();

    buffer.writeln('# FLUTTER PROJECT ANALYSIS\n');

    // Struktur
    buffer.writeln('## Project Structure');
    buffer.writeln('Pubspec: ${analysis['structure']['has_pubspec']}');
    buffer.writeln('Main.dart: ${analysis['structure']['has_main']}');
    buffer.writeln('Android: ${analysis['structure']['has_android']}');
    buffer.writeln('iOS: ${analysis['structure']['has_ios']}');
    buffer.writeln('Web: ${analysis['structure']['has_web']}');
    buffer.writeln(
      'Features: ${(analysis['structure']['features'] as List).join(', ')}',
    );
    buffer.writeln();

    // Dependencies
    buffer.writeln('## Dependencies');
    buffer.writeln('pubspec.yaml:');
    buffer.writeln('```yaml');
    buffer.writeln(analysis['dependencies']['pubspec_content'] ?? 'Not found');
    buffer.writeln('```\n');

    if (analysis['dependencies']['has_lockfile'] == true) {
      buffer.writeln('Has pubspec.lock: ✅');
    } else {
      buffer.writeln('Has pubspec.lock: ❌ (Need to run pub get)');
    }
    buffer.writeln();

    // Configuration
    buffer.writeln('## Configuration');
    if (analysis['configuration']['android_build_gradle'] != null) {
      buffer.writeln('android/app/build.gradle:');
      buffer.writeln('```gradle');
      buffer.writeln(analysis['configuration']['android_build_gradle']);
      buffer.writeln('```\n');
    }

    // Issues
    buffer.writeln('## Issues & Errors');
    final issues = analysis['issues'];

    buffer.writeln('### Pub Get Result');
    buffer.writeln('Exit Code: ${issues['pub_get_exit_code']}');
    if (issues['pub_get_exit_code'] != 0) {
      buffer.writeln('STDERR:');
      buffer.writeln('```');
      buffer.writeln(issues['pub_get_stderr']);
      buffer.writeln('```');
    }
    buffer.writeln();

    buffer.writeln('### Flutter Analyze Result');
    buffer.writeln('Exit Code: ${issues['analyze_exit_code']}');
    if (issues['analyze_exit_code'] != 0) {
      buffer.writeln('Output:');
      buffer.writeln('```');
      buffer.writeln(issues['analyze_output']);
      buffer.writeln('```');
    }
    buffer.writeln();

    // Flutter Info
    buffer.writeln('## Flutter Environment');
    buffer.writeln('```');
    buffer.writeln(analysis['flutter_info']['version'] ?? 'Unknown');
    buffer.writeln('```\n');

    buffer.writeln('## Instructions for AI');
    buffer.writeln('Please analyze the above information and:');
    buffer.writeln('1. Identify any errors or issues');
    buffer.writeln('2. Suggest specific fixes (file paths + exact changes)');
    buffer.writeln('3. Prioritize fixes by importance');
    buffer.writeln('4. Use the apply_code_fix tool to apply each fix');

    return buffer.toString();
  }
}
