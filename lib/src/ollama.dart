import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'cli.dart';
import 'config.dart' as cfg;
import 'system.dart';

/// Default Ollama API base URL
const String defaultUrl = 'http://localhost:11434';

/// Invokes the Ollama API with the provided prompt.
Future<void> invokeOllama(
  String model,
  String prompt,
  bool includeClipboard,
) async {
  final spinner = animatePrompt();

  try {
    prompt = await preparePrompt(prompt, includeClipboard);
    final apiBase = getApiBase();
    final request = http.Request('POST', Uri.parse('$apiBase/api/generate'));
    request.body = jsonEncode({
      "model": getModel(model),
      "system": cfg.systemPrompt,
      "prompt": prompt,
    });

    final streamedResponse = await request.send();
    if (streamedResponse.statusCode == 200) {
      // Listen to the response stream
      await streamedResponse.stream.transform(utf8.decoder).forEach((chunk) {
        cancelAnimation(spinner);
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
  } finally {
    if (spinner.isActive) {
      cancelAnimation(spinner);
    }
  }

  // Print the closing tag for the AI response
  print(cfg.config[cfg.cfgOutputEnd]);
}

/// Prepares the prompt, potentially including clipboard content.
Future<String> preparePrompt(String prompt, bool includeClipboard) async {
  if (prompt.isEmpty) {
    fail('No prompt provided', 64);
  }

  // Include clipboard content if the flag is set
  if (includeClipboard) {
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

/// Gets the API base URL from the environment or configuration.
String getApiBase() {
  final apiBase =
      cfg.config[cfg.cfgOllamaApiBase] ??
      Platform.environment[cfg.cfgOllamaApiBase] ??
      defaultUrl;

  if (apiBase.isEmpty) {
    fail(
      'No Ollama API base URL specified. Please set the OLLAMA_API_BASE environment variable or use the --config option.',
    );
  }
  return apiBase;
}

/// Gets the model to use for the Ollama API.
String getModel(String model) {
  if (model.isEmpty) {
    model =
        cfg.config[cfg.cfgOllamaModel] ??
        Platform.environment[cfg.cfgOllamaModel] ??
        '';
  }
  if (model.isEmpty) {
    fail(
      'No model specified. Please set the OLLAMA_MODEL environment variable, use the --model option or configure a model via --config.',
    );
  }
  return model;
}
