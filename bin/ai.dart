import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;

/// Default Ollama API base URL
const String defaultUrl = 'http://localhost:11434';

/// The default prompt for the AI assistant.
const String defaultPrompt =
    "You are a helpful terminal assistant. Provide concise assistance with terminal commands. "
    "Operating system: \$platform. "
    "User: '\$user', shell: \$shell. "
    "Do not use markdown formatting. "
    "Exclude the shell prompt from command suggestions. "
    "Keep responses brief, ending with the proposed command."
    "Highlight the proposed command with \$code, and reset color at the end with \x1B[0m. ";

/// The name of the configuration file.
const configFileName = '.ai_config';

/// The settings for the config fily
const _cfgOutputStart = 'OUTPUT_START';
const _cfgOutputEnd = 'OUTPUT_END';
const _cfgCodeColor = 'CODE_COLOR';
const _cfgOllamaModel = 'OLLAMA_MODEL';
const _cfgOllamaApiBase = 'OLLAMA_API_BASE';
const _cfgSystemPrompt = 'SYSTEM_PROMPT';

/// Following defaults, override via config file.
Map<String, String> _defaults = {
  _cfgOutputStart: '\x1B[32m✨ ', // Default: green text for AI start
  _cfgOutputEnd: '\x1B[0m\x1B[32m', // Default: reset
  _cfgCodeColor: '\x1b[38;2;255;100;0m', // Default: orange text for code
  _cfgSystemPrompt: defaultPrompt,
};

/// The effective configuration map, initialized with defaults.
Map<String, String> _config = {..._defaults};

/// Flag to include clipboard content in the prompt.
bool _includeClipboard = false;

/// Builds the system prompt.
String get systemPrompt {
  String prompt = _config[_cfgSystemPrompt] ?? '';
  return prompt
      .replaceAll("\$platform", Platform.operatingSystem)
      .replaceAll("\$user", detectUser())
      .replaceAll("\$shell", detectShell())
      .replaceAll("\$code", _config[_cfgCodeColor] ?? '');
}

/// A simple CLI tool to interact with the Ollama API.
Future<void> main(List<String> args) async {
  ArgParser parser = setupArgParser();
  var commands = parser.parse(args);

  // Load config and setup things
  _config.addAll(await readConfig(getConfigFile()));

  if (commands.flag('help')) {
    await printUsage(parser);
  } else if (commands.flag('config-list')) {
    await printConfig();
  } else if (commands.option('config') != null) {
    await updateConfig(commands.option('config') ?? '');
  } else {
    await execute(commands);
  }
  exit(0);
}

/// Executes the prompt using the provided commands.
///
Future<void> execute(ArgResults commands) async {
  final model = commands.option('model') ?? '';
  final prompt = commands.rest.join(' ');
  _includeClipboard = commands.flag('clip');
  await invokeOllama(model, prompt);
}

/// Sets up the argument parser for the CLI tool.
ArgParser setupArgParser() {
  var parser = ArgParser();
  parser.addFlag(
    'help',
    abbr: 'h',
    help: 'Display help information',
    negatable: false,
  );
  parser.addFlag(
    'clip',
    abbr: 'p',
    help: 'Include clipboard content in the prompt',
    negatable: false,
  );
  parser.addOption('model', abbr: 'm', help: 'Specify the Ollama model');
  parser.addOption(
    'config',
    abbr: 'c',
    help: 'Set a configuration property: key=value',
  );
  parser.addFlag(
    'config-list',
    abbr: 'l',
    help: 'List the current configuration',
    negatable: false,
  );
  return parser;
}

/// Prints the current configuration file settings.
Future<void> printConfig() async {
  final config = await readConfig(getConfigFile());
  config.forEach((k, v) => print('$k=$v'));
  final model = config[_cfgOllamaModel];
  if (model == null || model.isEmpty) {
    print('$_cfgOllamaModel=(not configured)');
  }
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
File getConfigFile() => File(
  '${Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']}/$configFileName',
);

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
    config.addAll(
      Map.fromEntries(
        contents.split('\n').where((line) => line.contains('=')).map((line) {
          final idx = line.indexOf('=');
          return MapEntry(
            line.substring(0, idx).toUpperCase().trim(),
            line.substring(idx + 1).trim(),
          );
        }),
      ),
    );
  }
  return config;
}

/// Invokes the Ollama API with the provided prompt.
///
Future<void> invokeOllama(String model, String prompt) async {
  // Print the opening tag for the AI response
  _printStart();
  final spinner = _animatePrompt();

  try {
    prompt = await preparePrompt(prompt);
    final config = await readConfig(getConfigFile());
    final apiBase = getApiBase(config);
    final request = http.Request('POST', Uri.parse('$apiBase/api/generate'));
    request.body = jsonEncode({
      "model": getModel(model),
      "system": systemPrompt,
      "prompt": prompt,
    });

    final streamedResponse = await request.send();
    if (streamedResponse.statusCode == 200) {
      // Listen to the response stream
      await streamedResponse.stream.transform(utf8.decoder).forEach((chunk) {
        _cancelAnimation(spinner);
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
  print(_config[_cfgOutputEnd]);
}

/// Prints the start tag for the AI response.
///
void _printStart() {
  stdout.write(_config[_cfgOutputStart]);
}

/// Converts a stream of strings to a single string.
///
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
      config[_cfgOllamaApiBase] ??
      Platform.environment[_cfgOllamaApiBase] ??
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
String getModel(String model) {
  if (model.isEmpty) {
    model = getModelFromConfig();
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
String getModelFromConfig() =>
    _config[_cfgOllamaModel] ?? Platform.environment[_cfgOllamaModel] ?? '';

/// Prints the usage information for the CLI tool.
///
Future<void> printUsage(ArgParser parser) async {
  print('Usage: ai [options] <prompt>');
  print(parser.usage);

  final model = getModelFromConfig();
  if (model.isNotEmpty) {
    print('Current model: $model');
  } else {
    print('Current model: (not configured)');
  }
}

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

/// Prints an error message and exits the program with the specified exit code.
void fail(String message, [int exitCode = 1]) {
  stderr.writeln('Error: $message');
  print(_config[_cfgOutputEnd]); // Print the closing tag for the AI response
  exit(exitCode);
}

/// Animates a spinner on the console.
///
/// Returns a [Timer] that can be cancelled to stop the animation.
Timer _animatePrompt() {
  final spinnerChars = ['|', '/', '-', r'\'];
  int i = 0;
  return Timer.periodic(Duration(milliseconds: 100), (timer) {
    stdout.write('\r${spinnerChars[i++ % spinnerChars.length]}');
  });
}

/// Cancels the spinner animation and prints the start tag.
///
void _cancelAnimation(Timer spinner) {
  if (spinner.isActive) {
    spinner.cancel();
    stdout.write('\r'); // Clear the spinner
    _printStart();
  }
}
