import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;

/// The default URL for the Ollama API.
const String defaultUrl = 'http://localhost:11434';

/// The name of the configuration file.
const configFileName = '.ai_config';

/// Flag to include clipboard content in the prompt.
bool _includeClipboard = false;

/// Builds the system prompt.
String get systemPrompt {
  return "You are a helpful terminal assistant. Help the user with their terminal commands. "
      "Operating system is ${Platform.operatingSystem}. "
      "Current user with username='${Platform.environment['USERNAME']}' is running in shell: ${detectShell()}. "
      "Do not use any markdown formatting. "
      "When you propose a command, do not include the prompt in the command. "
      "Keep your answer very short, and end it with the command proposal. ";
}

/// A simple CLI tool to interact with the Ollama API.
Future<void> main(List<String> args) async {
  ArgParser parser = setupArgParser();
  var commands = parser.parse(args);

  if (commands.flag('help')) {
    await printUsage(parser);
  } else if (commands.option('config') != null) {
    await updateConfig(commands.option('config') ?? '');
  } else {
    final model = commands.option('model') ?? '';
    final prompt = commands.rest.join(' ');
    _includeClipboard = commands.flag('clip');
    await invokeOllama(model, prompt);
  }
  exit(0);
}

/// Sets up the argument parser for the CLI tool.
ArgParser setupArgParser() {
  var parser = ArgParser();
  parser.addFlag('help', abbr: 'h', help: 'Display help information');
  parser.addFlag(
    'clip',
    abbr: 'p',
    help: 'Include clipboard content in the prompt',
  );
  parser.addOption('model', abbr: 'm', help: 'Specify the Ollama model');
  parser.addOption(
    'config',
    abbr: 'c',
    help: 'Set a configuration property: key=value',
  );
  return parser;
}

/// Updates the configuration by setting an property.
///
Future<void> updateConfig(String setting) async {
  final parts = setting.split('=');
  if (parts.length != 2) {
    fail('Invalid configuration format. Use key=value format.');
  }
  final key = parts[0].trim().toUpperCase();
  final value = parts[1].trim();

  final configFile = getConfigFile();
  final config = await readConfig(configFile);
  config[key] = value;
  await writeConfig(config, configFile);
}

/// Gets the configuration file path.
///
File getConfigFile() {
  final configFile = File(
    '${Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']}/$configFileName',
  );
  return configFile;
}

/// Writes the configuration to the specified file.
///
Future<void> writeConfig(Map<String, String> config, File configFile) async {
  final newContents = config.entries
      .map((e) => '${e.key.toUpperCase()}=${e.value}')
      .join('\n');
  await configFile.writeAsString(newContents);
}

/// Reads the configuration from the specified file.
///
Future<Map<String, String>> readConfig(File configFile) async {
  Map<String, String> config = {};
  if (!await configFile.exists()) {
    return config; // Return empty config if file does not exist
  }

  final contents = await configFile.readAsString();
  if (contents.isNotEmpty) {
    config = Map.fromEntries(
      contents.split('\n').where((line) => line.contains('=')).map((line) {
        final idx = line.indexOf('=');
        return MapEntry(
          line.substring(0, idx).toUpperCase().trim(),
          line.substring(idx + 1).trim(),
        );
      }),
    );
  }
  return config;
}

/// Invokes the Ollama API with the provided prompt.
///
Future<void> invokeOllama(String model, String prompt) async {
  // Print the opening tag for the AI response
  stdout.write('<ai>');

  try {
    prompt = await preparePrompt(prompt);
    final config = await readConfig(getConfigFile());
    final apiBase = getApiBase(config);
    final request = http.Request('POST', Uri.parse('$apiBase/api/generate'));
    request.body = jsonEncode({
      "model": getModel(model, config),
      "system": systemPrompt,
      "prompt": prompt,
    });

    final streamedResponse = await request.send();
    if (streamedResponse.statusCode == 200) {
      // Listen to the response stream
      await streamedResponse.stream.transform(utf8.decoder).forEach((chunk) {
        // Print only the generated token without a line break
        final token = jsonDecode(chunk) as Map<String, dynamic>;
        stdout.write(token['response']);
      });
    } else {
      final msg = await streamedResponse.stream.toStringStream().first;
      fail('Ollama failed: ${streamedResponse.statusCode} $msg');
    }
  } on SocketException {
    fail('Ollama server not running!');
  }

  // Print the closing tag for the AI response
  print('\n</ai>');
}

Future<String> preparePrompt(String prompt) async {
  if (prompt.isEmpty) {
    fail('No prompt provided', 64);
  }

  // Include clipboard content if the flag is set
  if (_includeClipboard) {
    try {
      final content = await getFromClipboard();
      if (content != null && content.isNotEmpty) {
        prompt = '---\nLAST command output:\n$content\n---\n$prompt';
      }
    } catch (e) {
      fail('Failed to read clipboard content: $e', 65);
    }
  }
  return prompt;
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

/// Gets the API base URL from the environment or configuration.
///
String getApiBase(Map<String, String> config) {
  final apiBase =
      config['OLLAMA_API_BASE'] ??
      Platform.environment['OLLAMA_API_BASE'] ??
      defaultUrl;

  if (apiBase.isEmpty) {
    fail(
      'No Ollama API base URL specified. Please set the OLLAMA_API_BASE environment variable or use the --config option.',
    );
  }
  return apiBase;
}

/// Gets the model to use for the Ollama API.
///
String getModel(String model, Map<String, String> config) {
  if (model.isEmpty) {
    model = getModelFromConfig(config);
  }
  if (model.isEmpty) {
    fail(
      'No model specified. Please set the OLLAMA_MODEL environment variable, use the --model option or configure a model via --config.',
    );
  }
  return model;
}

/// Gets the model from the configuration or environment variables.
///
String getModelFromConfig(Map<String, String> config) =>
    config['OLLAMA_MODEL'] ?? Platform.environment['OLLAMA_MODEL'] ?? '';

/// Prints the usage information for the CLI tool.
///
Future<void> printUsage(ArgParser parser) async {
  print('Usage: ai [options] <prompt>');
  print(parser.usage);
  // Print the currently configured model
  final config = await readConfig(getConfigFile());

  final model = getModelFromConfig(config);
  if (model.isNotEmpty) {
    print('Current model: $model');
  } else {
    print('Current model: (not configured)');
  }
}

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

/// Prints an error message and exits the program with the specified exit code.
void fail(String message, [int exitCode = 1]) {
  stderr.writeln('Error: $message');
  print('</ai>'); // Print the closing tag for the AI response
  exit(exitCode);
}
