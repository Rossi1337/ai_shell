# Ollama Powered Terminal/Shell AI Helper

This tool enhances your command-line experience by answering questions, proposing commands, analyzing command output, and helping correct errors—all powered by Ollama AI.

When you invoke it with a prompt, your question is sent to Ollama, and the AI's response is printed to your terminal. The tool automatically collects useful context and sends it along with your question to improve the quality of the answer.

**Context sent to Ollama includes:**
- The current operating system you use
- The current shell you are running in
- The shell's last full history (see [Activating Shell History](#activating-shell-history) below)

---

## Usage

Simply run the command followed by your question:

```shell
ai How can I switch to my home directory?
```

A typical response might look like:

```shell
<ai>You can switch to your home directory by using the `cd ~` command.

Command proposal: `cd ~`
</ai>
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
export OLLAMA_MODEL=llama3
```

You can also set the model at runtime using the `--model` option:

```shell
ai --model llama3 "Your prompt here"
```

---

## Activating Shell History

**Work in progress** This feature is currently not working. 

To provide the AI with access to your console output, you need to persist your shell history. **Warning:** This may include sensitive information such as passwords. Clean up these files when no longer needed.

### Windows PowerShell

Start logging all console output:

```shell
Start-Transcript
```

Stop logging:

```shell
Stop-Transcript
```

### Linux Shells

To capture shell output, use the `script` command from the [bsdutils](https://manpages.debian.org/bullseye/bsdutils/script.1.en.html) package:

```shell
script output_log.txt
```

Alternatively, use `tee` to store all output to a file:

```shell
bash | tee output_log.txt
```

---

## Building

- Entrypoint: `bin/`
- Library code: `lib/`
- Example unit tests: `test/`

To build the executable, run:

```shell
dart compile exe bin/ai.dart
```

---

## Further Reading

- [Ollama documentation](https://ollama.com/docs)

