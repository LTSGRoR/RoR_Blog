#!/bin/sh
set -eu

# Start Ollama server and keep it running.
exec ollama serve
