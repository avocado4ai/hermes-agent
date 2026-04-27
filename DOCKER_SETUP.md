# Hermes Agent - Docker Setup (Ollama + Telegram + MCP)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Host (macOS)                    │
│                                                             │
│  ┌─────────────────────┐    ┌─────────────────────┐     │
│  │   hermes-gateway   │    │ hermes-dashboard  │     │
│  │   (telegram bot)   │    │   port: 9119       │     │
│  │   network: host    │    │   network: host    │     │
│  └─────────────────────┘    └─────────────────────┘     │
│           │                           │                     │
│           ▼                           ▼                     │
│  ┌─────────────────────────────────────────────────┐   │
│  │         ~/.hermes/ (volume mount)               │   │
│  │  ├── config.yaml  (env var expansion)          │   │
│  │  ├── .env          (secrets)                   │   │
│  │  ├── sessions/                                 │   │
│  │  ├── logs/                                     │   │
│  │  └── skills/                                    │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
          ┌────────────────────────────┐
          │    Ollama Servers       │
          │  192.168.1.118:11434  │
          │  100.127.199.8:11434  │
          │  (fallback)              │
          └────────────────────────────┘
                           │
                           ▼
                    gemma4:latest
```

## Services

### 1. Gateway (`hermes-gateway`)
- **Image**: `hermes-agent:latest`
- **Network**: `host` (required for Telegram polling)
- **Port**: No exposed port (uses Telegram API directly)
- **Function**: Runs Telegram bot, cron scheduler, MCP servers

### 2. Dashboard (`hermes-dashboard`)
- **Image**: `hermes-agent:latest`
- **Network**: `host`
- **Port**: **9119** 
- **Access**: `http://localhost:9119`

## Configuration Files

### `~/.hermes/config.yaml`
```yaml
model:
  default: gemma4:latest
  provider: ollama
  context_length: 131072

mcp_servers:
  n8n-mcp:
    command: "npx"
    args: ["n8n-mcp"]
    env:
      MCP_MODE: "stdio"
      LOG_LEVEL: "error"
      DISABLE_CONSOLE_OUTPUT: "true"
      N8N_API_URL: "${N8N_API_URL}"
      N8N_API_KEY: "${N8N_API_KEY}"
  ssh-shuli:
    command: "npx"
    args: ["-y", "ssh-mcp", "--", "--host=192.168.1.118", "--port=22", "--user=dev", "--password=${SSH_SHULI_PASSWORD}"]
  chrome-devtools:
    command: "npx"
    args: ["-y", "chrome-devtools-mcp@latest"]
  n8n-workflows-docs:
    command: "npx"
    args: ["mcp-remote", "https://gitmcp.io/Zie619/n8n-workflows"]
  whatsapp:
    command: "/Users/yaronel/.opencode/skills/lan-server-connect/whatsapp-mcp-connect.sh"
    args: []

platforms:
  telegram:
    enabled: true
    bot_token: "${TELEGRAM_BOT_TOKEN}"
    allowed_user_ids:
      - <your-telegram-user-id>
```

### `~/.hermes/.env`
```
TELEGRAM_BOT_TOKEN=<your-telegram-bot-token>
TELEGRAM_ALLOWED_USERS=<your-telegram-user-id>
GROQ_API_KEY=<your-groq-api-key>
HF_TOKEN=<your-huggingface-token>
OPENROUTER_API_KEY=<your-openrouter-api-key>

OLLAMA_HOST=http://192.168.1.118:11434
HERMES_INFERENCE_PROVIDER=custom
HERMES_MODEL=gemma4:latest
HERMES_MODEL_CONTEXT_OVERRIDE=131072

# MCP servers
N8N_API_URL=http://192.168.1.118:5678
N8N_API_KEY=<your-n8n-api-key>
SSH_SHULI_PASSWORD=<your-ssh-password>
GITHUB_TOKEN=<your-github-token>
```

## Ollama Provider (Code Changes)

### `hermes_cli/runtime_provider.py`
Added handler for `ollama` provider:
```python
if provider == "ollama":
    # Local Ollama: try hosts in order: 192.168.1.118 → 100.127.199.8 → localhost
    base_url = "http://192.168.1.118:11434"
    api_key = "no-key-required"
    # Quick health check to verify the endpoint is reachable
    try:
        import requests
        resp = requests.get(base_url + "/api/tags", timeout=2)
        if not resp.ok:
            base_url = "http://100.127.199.8:11434"
            resp = requests.get(base_url + "/api/tags", timeout=2)
            if not resp.ok:
                base_url = "http://localhost:11434"
                resp = requests.get(base_url + "/api/tags", timeout=2)
                if not resp.ok:
                    raise AuthError("No accessible Ollama endpoint found")
    except Exception as e:
        raise AuthError(f"Ollama connection failed: {e}")
    # Add /v1 for OpenAI-compatible API
    base_url = base_url.rstrip("/") + "/v1"
    return {
        "provider": "ollama",
        "api_mode": "chat_completions",
        "base_url": base_url,
        "api_key": api_key,
        "source": "config",
        "requested_provider": requested_provider,
    }
```

### `hermes_cli/auth.py`
Added ollama to provider aliases:
```python
if normalized == "ollama" or normalized == "ollama-cloud":
    return normalized
```

### `hermes_cli/models.py`
Added `fetch_ollama_local_models()` function:
```python
def fetch_ollama_local_models(
    *,
    force_refresh: bool = False,
) -> list[str]:
    """Fetch local Ollama models from the running Ollama instance."""
    hosts = ["http://192.168.1.118:11434", "http://100.127.199.8:11434", "http://localhost:11434"]
    import urllib.request
    import json

    for base_url in hosts:
        try:
            resp = urllib.request.urlopen(base_url + "/api/tags", timeout=3)
            data = json.loads(resp.read())
            models = [m["name"] for m in data.get("models", [])]
            if models:
                return models
        except Exception:
            continue

    return []
```

### `hermes_cli/model_switch.py`
Registered ollama models in curated list:
```python
# Ollama local uses dynamic discovery from running Ollama instance
if "ollama" not in curated:
    from hermes_cli.models import fetch_ollama_local_models
    curated["ollama"] = fetch_ollama_local_models()
```

## MCP Servers Migrated from Claude Desktop

| Server | Transport | Tools | Status |
|--------|-----------|-------|--------|
| n8n-mcp | stdio (npx) | 24 tools | ✅ enabled |
| ssh-shuli | stdio (ssh-mcp) | - | ✅ enabled |
| chrome-devtools | stdio (npx) | - | ✅ enabled |
| n8n-workflows-docs | mcp-remote (HTTP) | - | ✅ enabled |
| whatsapp | stdio (script) | - | ✅ enabled |

## Docker Commands

### Start all services
```bash
cd /Users/yaronel/ai-tools/hermes-agent
docker compose up -d
```

### Start individual services
```bash
# Gateway only
docker run -d --name hermes-gateway --network host \
  -v ~/.hermes:/opt/data \
  -e HERMES_UID=$(id -u) \
  -e HERMES_GID=$(id -g) \
  --env-file ~/.hermes/.env \
  hermes-agent:latest gateway run

# Dashboard only (port 9119)
docker run -d --name hermes-dashboard --network host \
  -v ~/.hermes:/opt/data \
  -e HERMES_UID=$(id -u) \
  -e HERMES_GID=$(id -g) \
  --env-file ~/.hermes/.env \
  hermes-agent:latest dashboard --host 127.0.0.1 --no-open
```

### Stop all services
```bash
docker compose down
# OR
docker stop hermes-gateway hermes-dashboard
docker rm hermes-gateway hermes-dashboard
```

### View logs
```bash
# Gateway logs
docker logs hermes-gateway -f

# Dashboard logs
docker logs hermes-dashboard -f

# Gateway application logs
docker exec hermes-gateway cat /opt/data/logs/gateway.log | tail -50
```

## Building the Docker Image

```bash
cd /Users/yaronel/ai-tools/hermes-agent
docker compose build --no-cache
```

**Note**: The build fixes esbuild version mismatch:
```dockerfile
# Fix esbuild version mismatch - remove conflicting binary and reinstall
RUN cd web && \
    rm -rf node_modules/esbuild && \
    npm install --save-dev esbuild@latest && \
    rm -rf node_modules/.cache/esbuild 2>/dev/null || true
```

## Telegram Bot

- **Bot**: `@your_bot_name`
- **Token**: `<your-telegram-bot-token>`
- **Allowed User ID**: `<your-telegram-user-id>`
- **Mode**: Polling (not webhook)

### Telegram Conflict Resolution
If you see `Conflict: terminated by other getUpdates request`:
1. Stop ALL hermes containers: `docker stop $(docker ps -aq --filter "name=hermes")`
2. Kill ALL host processes: `pkill -9 -f hermes`
3. Wait 60 seconds (Telegram polling timeout)
4. Start fresh: `docker compose up -d`

## Web Search with SearXNG

### Configuration
SearXNG runs in a separate container (`searxng`) with `--network host`, listening on port `8080`.
Both hermes-gateway and SearXNG share host networking, so `127.0.0.1:8080` works from any container.

**config.yaml:**
```yaml
auxiliary:
  web_search:
    provider: searxng
    base_url: 'http://127.0.0.1:8080'
    api_key: ''
    timeout: 30
    extra_body: {}
```

### Start SearXNG
```bash
docker run -d --name searxng --network host \
  -e SEARXNG_BASE_URL=http://localhost:8080/ \
  searxng/searxng:latest

# Enable JSON format (required once after first start)
docker exec searxng python3 -c "
import re
with open('/etc/searxng/settings.yml', 'r') as f:
    content = f.read()
content = content.replace('  formats:\n    - html\n', '  formats:\n    - html\n    - json\n')
with open('/etc/searxng/settings.yml', 'w') as f:
    f.write(content)
"
docker restart searxng
```

### Test SearXNG
```bash
# From host
curl "http://127.0.0.1:8080/search?q=test&format=json" | python3 -m json.tool | head -20
```

### SearXNG Container
```bash
# Status
docker ps | grep searxng

# Logs
docker logs searxng --tail 50

# Restart if needed
docker restart searxng
```

## Complete Service Overview

| Service | Container | Network | Port | Status |
|---------|-----------|---------|------|--------|
| Gateway | `hermes-gateway` | host | - | ✅ Telegram connected |
| Dashboard | `hermes-dashboard` | host | **9119** | ✅ `http://localhost:9119` |
| SearXNG | `searxng` | host | 8080 | ✅ Web search |
| Ollama | Remote | - | 192.168.1.118:11434 | ✅ `gemma4:latest` |
| Telegram | Bot `@your_bot_name` | - | - | ✅ Connected |

## Troubleshooting

### Port 9120 still in use
```bash
pkill -9 -f "start_server.*9120"
pkill -9 -f "hermes.*9120"
```

### Telegram conflict persists
```bash
# 1. Stop everything
docker compose down

# 2. Kill host processes
pkill -9 -f hermes

# 3. Wait FULL 60 seconds
sleep 65

# 4. Start fresh
docker compose up -d
```

### Ollama not connecting
```bash
# Test from container
docker exec hermes-gateway curl -s http://192.168.1.118:11434/api/tags | python3 -m json.tool | head -20
```

### Dashboard not accessible at 9119
```bash
# Check if dashboard container is running
docker ps | grep dashboard

# Check logs
docker logs hermes-dashboard | tail -20

# Verify port (should be 9119, NOT 9120)
docker exec hermes-dashboard printenv | grep PORT
```

## File Locations

| File | Location | Purpose |
|------|----------|---------|
| Dockerfile | `/Users/yaronel/ai-tools/hermes-agent/Dockerfile` | Image build |
| Compose | `/Users/yaronel/ai-tools/hermes-agent/docker-compose.yml` | Multi-service setup |
| Config | `~/.hermes/config.yaml` | Hermes configuration |
| Secrets | `~/.hermes/.env` | API keys, tokens, passwords |
| Logs | `~/.hermes/logs/` | Application logs |
| Sessions | `~/.hermes/sessions/` | Chat sessions |

## Key Points

1. **Only run in Docker** - Don't run host processes (causes Telegram conflicts)
2. **Port 9119** - Dashboard uses 9119, NOT 9120
3. **Secrets in `.env`** - config.yaml uses `${ENV_VAR}` expansion
4. **Ollama fallback** - Tries 192.168.1.118 → 100.127.199.8 → localhost
5. **Telegram timeout** - Wait 60s after stopping before restarting
6. **MCP servers** - All 5 from Claude Desktop migrated
