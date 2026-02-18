# recipe-voice-agent

A containerized voice interface for [recipe-lm](https://github.com/glee2429/recipe-lm) powered by [ClawdBot](https://github.com/clawdbot/clawdbot) (OpenClaw) and [ClawdTalk](https://github.com/team-telnyx/clawdtalk-client) (Telnyx).

Call a phone number, ask for a recipe, and the agent generates one using a fine-tuned Gemma-2B model deployed on HuggingFace Spaces.

## Architecture

```
[Phone Call] --> [Telnyx / ClawdTalk] --> [outbound WSS] --> [ClawdBot Container]
                                                                   |
                                                             [exec: curl]
                                                                   |
                                                                   v
                                                     [HF Space POST /generate]
                                              (ClaireLee2429-recipe-lm-api.hf.space)
```

- **Single Docker container**: OpenClaw gateway (foreground) + ClawdTalk WebSocket client (background)
- **No local GPU needed**: Recipe generation happens on HuggingFace Spaces
- **Security**: Non-root user, loopback-only gateway, minimal tool permissions, secrets via env vars

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/glee2429/recipe-voice-agent.git
cd recipe-voice-agent

# 2. Configure secrets
cp .env.example .env
# Edit .env with your keys:
#   ANTHROPIC_API_KEY  - from https://console.anthropic.com
#   CLAWDTALK_API_KEY  - from https://clawdtalk.com
#   OPENCLAW_GATEWAY_TOKEN - generate with: openssl rand -hex 32

# 3. Build and run
docker compose up --build

# 4. Verify
curl http://127.0.0.1:18789/health
```

## Configuration

| File | Purpose |
|------|---------|
| `.env` | API keys and secrets (gitignored) |
| `config/openclaw.json` | Gateway config, tool permissions, skill entries |
| `workspace/AGENTS.md` | Agent identity and voice interaction rules |
| `workspace/SOUL.md` | Agent personality |
| `skills/recipe-generate/SKILL.md` | Recipe API integration (curl to HF Space) |

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `ANTHROPIC_API_KEY` | Yes | Anthropic API key for the agent's LLM |
| `CLAWDTALK_API_KEY` | Yes | ClawdTalk API key from clawdtalk.com |
| `OPENCLAW_GATEWAY_TOKEN` | Yes | Gateway auth token (random string) |
| `RECIPE_LM_API_URL` | No | Defaults to `https://ClaireLee2429-recipe-lm-api.hf.space` |
| `CLAWDTALK_SERVER` | No | Defaults to `https://clawdtalk.com` |

## Related Projects

- [recipe-lm](https://github.com/glee2429/recipe-lm) - Training pipeline and inference server
- [kitchen-genie](https://github.com/glee2429/kitchen-genie) - React web frontend
