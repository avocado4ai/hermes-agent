#!/bin/bash
# Hermes Agent Launcher
# Usage: 
#   ./run-hermes.sh "hi"            # Quick chat (deepseek model)
#   ./run-hermes.sh "hi qwen"       # With model shorthand passed to -m

cd "$(dirname "$0")"
source venv/bin/activate
source ~/.hermes/.env 2>/dev/null

python -m hermes_cli.main chat "$@"