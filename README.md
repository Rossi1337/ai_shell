# Ollama Powered Terminal/Shell AI Helper

This tool enhances your command-line experience by answering questions, proposing commands, analyzing command output, and helping correct errors—all powered by Ollama AI.

When you invoke it with a prompt, your question is sent to Ollama, and the AI's response is printed to your terminal. The tool automatically collects useful context and sends it along with your question to improve the quality of the answer.

**Context sent to Ollama includes:**
- The current operating system you use
- The current shell you are running in
- The content of the clipboard if you specify the --clip option

---

## Usage

Simply run the command followed by your question:

```shell
ai How can I switch to my home directory?
```

A typical response might look like:

```shell
✨ You can switch to your home directory by using the `cd ~` command.

Command proposal: `cd ~`
```

---

### Options

To see all available options, run:

```shell
ai --help
```

---

## Configuration
You can specify some settings in a settings file in the file ```~/.ai_config```.
If this file exists it will take precendence over the environment variables.    

### Ollama URL
This can be set in the config file via:
```
OLLAMA_API_BASE = <url>
```

alternatively set the `OLLAMA_API_BASE` environment variable to your Ollama server URL. 
If nothing is configured, the tool defaults to `http://localhost:11434`.

```shell
export OLLAMA_API_BASE=http://localhost:11434
```

### Model Selection

Before starting, you must specify the Ollama model.

This can be set in the config file via:
```
OLLAMA_MODEL = <modelname>
```

or by setting the `OLLAMA_MODEL` environment variable:

```shell
export OLLAMA_MODEL=gemma3:4b
```

You can also set the model at runtime using the `--model` option:

```shell
ai --model gemma3:4b "Your prompt here"
```

Which model should I use?`This depends on your hardware but in general I get good answers by using small models like gemma3:4b or the small phi models. They produce quick responses which are most of of the time good enough. I do not recommend to use a reasoning model as they take longer to process your input with only 
little improvements. If you have better hardware you can try bigger models but often their output is way to 
verbose so it will not give you always a overall better experience.

### Other Settings
You can also specify a prefix and suffix for the generated text. This is currently used to color the output of the AI. To do so specify in the config file: `OUTPUT_START` and `OUTPUT_END`

For example:
```shell
OUTPUT_START=\x1B[32m✨ 
OUTPUT_END=\x1B[0m
```

### Changing the system prompt
To set your own system prompt you can do so by setting in the config file `SYSTEM_PROMPT`

---

## Building

- Entrypoint: `bin/`
- Library code: `lib/`
- Example unit tests: `test/`

To build the executable, run:

```shell
dart compile exe bin/ai.dart
```
This will give you an `bin/ai.exe`
on Linux you may want to rename that one.

---

## Further Reading

- [Ollama documentation](https://ollama.com/docs)

