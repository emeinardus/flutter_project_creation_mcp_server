class PubspecTemplate {
  static String generate(String name, List<String> additionalDeps) {
    return '''
name: $name
description: A Flutter project with Clean Architecture
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.0.0

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
${additionalDeps.map((dep) => '  $dep: any').join('\n')}

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
''';
  }
}
