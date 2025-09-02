import 'dart:io';

import 'package:ai/src/cli.dart';
import 'package:ai/src/config.dart' as cfg;
import 'package:ai/src/ollama.dart';
import 'package:args/args.dart';

/// A simple CLI tool to interact with the Ollama API.
Future<void> main(List<String> args) async {
  ArgParser parser = setupArgParser();
  var commands = parser.parse(args);

  // Load config and setup things
  cfg.config.addAll(await cfg.readConfig(cfg.getConfigFile()));

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
Future<void> execute(ArgResults commands) async {
  final model = commands.option('model') ?? '';
  final prompt = commands.rest.join(' ');
  final includeClipboard = commands.flag('clip');
  await invokeOllama(model, prompt, includeClipboard);
}
