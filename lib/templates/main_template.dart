class MainTemplate {
  static String generate(String name) {
    return '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Für Web: ENVIRONMENT aus dart-define
// Für Android: Auch ENVIRONMENT (wird durch Flavor gesetzt)
const String environment = String.fromEnvironment('ENVIRONMENT', defaultValue: 'dev');

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '$name (\$environment)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: environment == 'prod' ? Colors.blue : Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text('$name'),
          backgroundColor: environment == 'prod' ? Colors.blue : Colors.deepPurple,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome to $name!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: environment == 'prod' ? Colors.blue : Colors.deepPurple,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Environment: \${environment.toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
''';
  }
}
