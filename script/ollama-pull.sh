#!/bin/sh
set -eu

MODEL_NAME="${AI_MODERATION_MODEL:-}"

if [ -z "$MODEL_NAME" ]; then
  echo "AI_MODERATION_MODEL is empty; skipping model pull."
  exit 0
fi

# Wait until Ollama is reachable.
until ollama list >/dev/null 2>&1; do
  echo "Waiting for Ollama server..."
  sleep 2
done

# Check if model is already present.
if ollama list | awk 'NR > 1 {print $1}' | grep -Fx "$MODEL_NAME" >/dev/null 2>&1; then
  echo "Model already present: $MODEL_NAME"
  exit 0
fi

# Pull the model and exit.
echo "Pulling model: $MODEL_NAME"
ollama pull "$MODEL_NAME"
echo "Model pull complete."
