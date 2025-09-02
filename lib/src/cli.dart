import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';

import 'config.dart' as cfg;

/// Prints an error message and exits the program with the specified exit code.
void fail(String message, [int exitCode = 1]) {
  stderr.writeln('Error: $message');
  stdout.write('\x1B[?25h'); // Show cursor
  print(
    cfg.config[cfg.cfgOutputEnd],
  ); // Print the closing tag for the AI response
  exit(exitCode);
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
  final config = await cfg.readConfig(cfg.getConfigFile());
  config.forEach((k, v) => print('$k=$v'));
  final model = config[cfg.cfgOllamaModel];
  if (model == null || model.isEmpty) {
    print('${cfg.cfgOllamaModel}=(not configured)');
  }
}

/// Updates the configuration by setting an property.
Future<void> updateConfig(String setting) async {
  final parts = setting.split('=');
  if (parts.length != 2) {
    fail('Invalid configuration format. Use key=value format.');
  }
  final key = parts[0].trim().toUpperCase();
  final value = parts[1].trim();
  final configFile = cfg.getConfigFile();
  final config = await cfg.readConfig(configFile);
  config[key] = value;
  await cfg.writeConfig(config, configFile);
}

/// Prints the usage information for the CLI tool.
Future<void> printUsage(ArgParser parser) async {
  print('Usage: ai [options] <prompt>');
  print(parser.usage);

  final model =
      cfg.config[cfg.cfgOllamaModel] ??
      Platform.environment[cfg.cfgOllamaModel] ??
      '';
  if (model.isNotEmpty) {
    print('Current model: $model');
  } else {
    print('Current model: (not configured)');
  }
}

/// Animates a spinner on the console.
///
/// Returns a [Timer] that can be cancelled to stop the animation.
Timer animatePrompt() {
  final spinnerChars =
      cfg.config[cfg.cfgSpinnerChars]?.split('') ?? ['|', '/', '-', r'\'];
  int i = 0;
  stdout.write('\x1B[?25l\x1b[38;2;255;100;0m'); // Hide cursor and set color
  return Timer.periodic(Duration(milliseconds: 100), (timer) {
    stdout.write('\r${spinnerChars[i++ % spinnerChars.length]}');
  });
}

/// Cancels the spinner animation and prints the start tag.
void cancelAnimation(Timer spinner) {
  if (spinner.isActive) {
    spinner.cancel();
    stdout.write('\r'); // Clear the spinner
    stdout.write('\x1B[?25h'); // Show cursor
    stdout.write(cfg.config[cfg.cfgOutputStart]);
  }
}
