import 'dart:io';

class EmulatorService {
  static Future<List<String>> listEmulators() async {
    try {
      final result = await Process.run('emulator', ['-list-avds']);
      if (result.exitCode != 0) {
        return [];
      }

      final output = result.stdout.toString().trim();
      if (output.isEmpty) {
        return [];
      }

      return output
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> startEmulator(String emulatorName) async {
    Process.start('emulator', [
      '-avd',
      emulatorName,
    ], mode: ProcessStartMode.detached);
  }

  static Future<void> waitForBoot() async {
    for (var i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 2));

      try {
        final result = await Process.run('adb', [
          'shell',
          'getprop',
          'sys.boot_completed',
        ]);
        if (result.stdout.toString().trim() == '1') {
          return;
        }
      } catch (e) {
        // ADB not ready, keep waiting...
      }
    }

    throw Exception('Emulator boot timeout after 120 seconds');
  }
}
