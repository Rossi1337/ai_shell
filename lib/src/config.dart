import 'dart:io';

import 'system.dart';

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
const cfgOutputStart = 'OUTPUT_START';
const cfgSpinnerChars = 'SPINNER_CHARS';
const cfgOutputEnd = 'OUTPUT_END';
const cfgCodeColor = 'CODE_COLOR';
const cfgOllamaModel = 'OLLAMA_MODEL';
const cfgOllamaApiBase = 'OLLAMA_API_BASE';
const cfgSystemPrompt = 'SYSTEM_PROMPT';

/// Following defaults, override via config file.
Map<String, String> defaults = {
  cfgOutputStart: '\x1B[0m\x1B[32m✨ ', // Default: green text for AI start
  cfgOutputEnd: '\x1B[0m\x1B[32m', // Default: reset
  cfgCodeColor: '\x1b[38;2;255;100;0m', // Default: orange text for code
  cfgSpinnerChars:
      '⠁⠂⠄⡀⡈⡐⡠⣀⣁⣂⣄⣌⣔⣤⣥⣦⣮⣶⣷⣿⡿⠿⢟⠟⡛⠛⠫⢋⠋⠍⡉⠉⠑⠡⢁', // Default spinner characters
  cfgSystemPrompt: defaultPrompt,
};

/// The effective configuration map, initialized with defaults.
Map<String, String> config = {...defaults};

/// Builds the system prompt.
String get systemPrompt {
  String prompt = config[cfgSystemPrompt] ?? '';
  return prompt
      .replaceAll("\$platform", Platform.operatingSystem)
      .replaceAll("\$user", detectUser())
      .replaceAll("\$shell", detectShell())
      .replaceAll("\$code", config[cfgCodeColor] ?? '');
}

/// Gets the configuration file path.
File getConfigFile() => File(
  '${Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']}/$configFileName',
);

/// Writes the configuration to the specified file.
Future<void> writeConfig(Map<String, String> config, File configFile) async {
  final newContents = config.entries
      .map((e) => '${e.key.toUpperCase()}=${e.value}')
      .join('\n');
  await configFile.writeAsString(newContents);
}

/// Reads the configuration from the specified file.
Future<Map<String, String>> readConfig(File configFile) async {
  Map<String, String> newConfig = {};
  if (!await configFile.exists()) {
    return newConfig; // Return empty config if file does not exist
  }

  final contents = await configFile.readAsString();
  if (contents.isNotEmpty) {
    newConfig.addAll(
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
  return newConfig;
}
