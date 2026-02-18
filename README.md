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
- **Security**: Non-root user, loopback-only gateway, minimal tool permissions (`exec` + `sessions_send` only), secrets via shell environment

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/glee2429/recipe-voice-agent.git
cd recipe-voice-agent

# 2. Export your API keys (add to ~/.zshrc or ~/.bashrc for persistence)
export ANTHROPIC_API_KEY=sk-ant-...   # from https://console.anthropic.com
export CLAWDTALK_API_KEY=cc_live_...  # from https://clawdtalk.com

# 3. Build and run
docker compose up --build

# 4. Verify
docker ps --filter name=recipe-voice-agent
```

> **Never paste API keys into an AI assistant chat.** Set them in your shell environment or a secrets manager, and let Docker Compose inherit them.

## Configuration

| File | Purpose |
|------|---------|
| `config/openclaw.json` | Gateway config, tool permissions, skill entries |
| `workspace/AGENTS.md` | Agent identity and voice interaction rules |
| `workspace/SOUL.md` | Agent personality |
| `skills/recipe-generate/SKILL.md` | Recipe API integration (curl to HF Space) |

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `ANTHROPIC_API_KEY` | Yes | Anthropic API key for the agent's LLM |
| `CLAWDTALK_API_KEY` | Yes | ClawdTalk API key from clawdtalk.com |
| `RECIPE_LM_API_URL` | No | Defaults to `https://ClaireLee2429-recipe-lm-api.hf.space` |

`OPENCLAW_GATEWAY_TOKEN` is auto-generated at container startup. `CLAWDTALK_SERVER` defaults to `https://clawdtalk.com`.

## Related Projects

- [recipe-lm](https://github.com/glee2429/recipe-lm) - Training pipeline and inference server
- [kitchen-genie](https://github.com/glee2429/kitchen-genie) - React web frontend
