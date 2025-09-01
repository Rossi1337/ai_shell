import 'dart:io';
import 'package:test/test.dart';
import '../bin/ai.dart';

void main() {
  /// Tests for the AI CLI tool
  group('Config file', () {
    late File configFile;

    /// Set up a temporary config file for testing
    setUp(() async {
      configFile = File('test/.test_ai_config');
      if (await configFile.exists()) await configFile.delete();
    });

    /// Clean up the temporary config file after tests
    tearDown(() async {
      if (await configFile.exists()) await configFile.delete();
    });

    /// Tests for reading and writing configuration
    test('writeConfig and readConfig roundtrip', () async {
      final config = {
        'OLLAMA_MODEL': 'test-model',
        'OLLAMA_API_BASE': 'http://test.invalid',
      };
      await writeConfig(config, configFile);
      final read = await readConfig(configFile);
      expect(read['OLLAMA_MODEL'], equals('test-model'));
      expect(read['OLLAMA_API_BASE'], equals('http://test.invalid'));
    });

    /// Tests for reading configuration
    test('readConfig returns empty map if file does not exist', () async {
      final file = File('test/.nonexistent_config');
      if (await file.exists()) await file.delete();
      final config = await readConfig(file);
      expect(config, isEmpty);
    });

    test('writeConfig stores keys as uppercase', () async {
      final config = {
        'ollama_model': 'lowercase-model',
        'OlLaMa_ApI_bAsE': 'http://mixedcase.invalid',
      };
      await writeConfig(config, configFile);
      final contents = await configFile.readAsString();
      expect(contents, contains('OLLAMA_MODEL=lowercase-model'));
      expect(contents, contains('OLLAMA_API_BASE=http://mixedcase.invalid'));
    });

    test('readConfig returns keys as uppercase', () async {
      var config2 = {'ollama_model': 'foo', 'OlLaMa_ApI_bAsE': 'bar'};
      await writeConfig(config2, configFile);
      final config = await readConfig(configFile);
      expect(config.containsKey('OLLAMA_MODEL'), isTrue);
      expect(config.containsKey('OLLAMA_API_BASE'), isTrue);
      expect(config['OLLAMA_MODEL'], equals('foo'));
      expect(config['OLLAMA_API_BASE'], equals('bar'));
    });
  });

  /// Tests for invoking the Ollama API
  group('getModel', () {
    /// Tests for getting the model from configuration or arguments
    test('returns model from argument if provided', () {
      expect(getModel('arg-model'), equals('arg-model'));
    });

    /// Tests for getting the model from configuration if argument is empty
    test('returns model from config if argument is empty', () {
      expect(getModel(''), equals('test-model'));
    });
  });
}
