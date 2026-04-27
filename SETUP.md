# Hermes Agent — Local Setup

Forked from [avocado4ai/hermes-agent](https://github.com/avocado4ai/hermes-agent) (NousResearch/hermes-agent).

## Stack

| Component | Value |
|-----------|-------|
| LLM Provider | Ollama (local, host machine) |
| Model | `gemma4:e4b` |
| Ollama endpoint | `http://localhost:11434` |
| Data volume | `hermes-agent_hermes-data` (Docker named volume) |
| Fallback LLM | Gemini (`GOOGLE_API_KEY` in `.env`) |

## Telegram Notification

`run.sh` sends a Telegram message to Yaron (`217441497`) via the `nanoMacClaw_bot` before starting the container.
Bot token and chat ID are hardcoded in `run.sh` (sourced from nanoclaw).

## Usage

```bash
./run.sh            # sends Telegram hello, then starts interactive CLI
./run.sh doctor     # diagnose configuration
./run.sh model      # switch model
./run.sh setup      # full setup wizard
./run.sh skills     # manage skills
./stop.sh           # stop and remove containers
```

## Files

```
hermes-agent/
├── Dockerfile              # upstream image definition
├── docker-compose.yml      # container config (provider, model, volume)
├── .env                    # API keys (Gemini fallback, etc.)
├── run.sh                  # start interactive session
├── stop.sh                 # stop containers
└── SETUP.md                # this file
```

## Configuration

### docker-compose.yml — key env vars

| Variable | Value | Purpose |
|----------|-------|---------|
| `HERMES_INFERENCE_PROVIDER` | `ollama` | Use local Ollama |
| `HERMES_MODEL` | `gemma4:e4b` | Default model |
| `OLLAMA_HOST` | `http://host.docker.internal:11434` | Reach host Ollama from container |

### Persisted config (inside Docker volume)

The container writes `config.yaml` and `.env` into the named volume on first run.
To inspect or edit:

```bash
docker run --rm -it -v hermes-agent_hermes-data:/data alpine sh
# files are at /data/config.yaml and /data/.env
```

To reset config (wipe sessions, skills, memories):

```bash
docker volume rm hermes-agent_hermes-data
```

## Changing the Model

**Option 1 — environment variable (docker-compose.yml):**
```yaml
environment:
  HERMES_MODEL: llama3.1:8b
```

**Option 2 — inside the CLI:**
```bash
./run.sh model
```

**Option 3 — edit config in volume directly:**
```bash
docker compose run --rm --entrypoint bash hermes \
  -c "sed -i 's/default:.*/default: \"llama3.1:8b\"/' /opt/data/config.yaml"
```

## Switching to Gemini

Edit `docker-compose.yml`:
```yaml
environment:
  HERMES_INFERENCE_PROVIDER: gemini
```

The `GOOGLE_API_KEY` is already set in `.env`.

## Available Ollama Models

```
gemma4:e4b        ← current default
gemma3:12b
gemma3:4b
llama3.1:8b
llama3.2:latest
qwen3.5:latest
qwen2.5-coder:1.5b-base
gpt-oss:20b
```
