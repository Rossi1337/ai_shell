import 'dart:convert';
import 'dart:io';

/// Detects the current user based on environment variables.
String detectUser() =>
    Platform.environment['USERNAME'] ??
    Platform.environment['USER'] ??
    'unknown';

/// Detects the current shell environment.
String detectShell() {
  final env = Platform.environment;
  if (env.containsKey('SHELL')) {
    return env['SHELL']!;
  } else if (env.containsKey('ComSpec') && !env.containsKey('PROMPT')) {
    return 'powershell'; // Powershell and cmd.exe are nearly indistinguishable
  } else if (env.containsKey('ComSpec') &&
      env['ComSpec']!.contains('cmd.exe')) {
    return 'cmd';
  } else {
    return 'unknown';
  }
}

/// Reads text from the system clipboard.
/// Supports Windows, macOS, and Linux (with xclip or xsel).
Future<String?> getFromClipboard() async {
  String? result;

  if (Platform.isWindows) {
    // Use PowerShell to get clipboard content
    final proc = await Process.start('powershell', [
      '-NoProfile',
      '-Command',
      'Get-Clipboard',
    ], runInShell: true);
    result = await proc.stdout.transform(utf8.decoder).join();
    await proc.stderr.drain();
  } else if (Platform.isMacOS) {
    // Use pbpaste on macOS
    final proc = await Process.start('pbpaste', [], runInShell: true);
    result = await proc.stdout.transform(utf8.decoder).join();
    await proc.stderr.drain();
  } else if (Platform.isLinux) {
    // Try xclip, then xsel
    try {
      final proc = await Process.start('xclip', [
        '-selection',
        'clipboard',
        '-o',
      ], runInShell: true);
      result = await proc.stdout.transform(utf8.decoder).join();
      await proc.stderr.drain();
      if (result.trim().isEmpty) throw Exception();
    } catch (_) {
      try {
        final proc = await Process.start('xsel', [
          '--clipboard',
          '--output',
        ], runInShell: true);
        result = await proc.stdout.transform(utf8.decoder).join();
        await proc.stderr.drain();
      } catch (_) {
        result = null;
      }
    }
  }

  return result;
}
