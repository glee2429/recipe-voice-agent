# recipe-voice-agent

A containerized voice interface for [recipe-lm](https://github.com/glee2429/recipe-lm) powered by [ClawdBot](https://github.com/clawdbot/clawdbot) (OpenClaw) and [ClawdTalk](https://github.com/team-telnyx/clawdtalk-client) (Telnyx).

Call a phone number, ask for a recipe, and the agent generates one using a fine-tuned Gemma-2B model deployed on HuggingFace Spaces. After reading the recipe, the agent offers to text it to you via SMS.

## Architecture

```
[Phone Call] --> [Telnyx / ClawdTalk] --> [outbound WSS] --> [ClawdBot Container]
                                                                   |
                                                             [exec: curl]
                                                                   |
                                                                   v
                                                     [HF Space POST /generate]
                                              (ClaireLee2429-recipe-lm-api.hf.space)
                                                                   |
                                                            [exec: sms.sh]
                                                                   |
                                                                   v
                                                     [ClawdTalk API --> Telnyx SMS]
```

- **Single Docker container**: OpenClaw gateway (foreground) + ClawdTalk WebSocket client (background)
- **Two models, separate roles**: Claude Haiku handles conversation and tool routing (the "brain"); recipe generation is done entirely by the fine-tuned Gemma-2B model on HuggingFace Spaces — Haiku never generates recipes itself
- **No local GPU needed**: Recipe inference happens on HuggingFace Spaces via API
- **SMS delivery**: After reading a recipe, the agent asks if you want it texted. SMS is sent via ClawdTalk's `sms.sh` script, which proxies through the ClawdTalk API to Telnyx
- **Security**: Non-root user, loopback-only gateway, deny-list tool permissions, secrets via shell environment

### How inference works

| Step | What happens | Model used |
|------|-------------|------------|
| 1 | Caller speaks, Telnyx transcribes to text | Telnyx STT |
| 2 | Agent understands the request and decides to call the recipe tool | Claude Haiku (Anthropic API) |
| 3 | Agent runs `curl` to HuggingFace Space `POST /generate` (SSE streaming) | Fine-tuned Gemma-2B (HF Space) |
| 4 | Agent reads the recipe aloud (ingredients, then directions) | Claude Haiku + Telnyx TTS |
| 5 | Agent asks: "Would you like me to text you the recipe?" | Claude Haiku |
| 6 | If yes, agent collects phone number and runs `sms.sh` to send SMS | ClawdTalk + Telnyx SMS |

The Anthropic API key is used **only** for the agent's conversational logic — understanding what the caller wants and deciding which tool to invoke. All recipe content comes from the [Gemma-2B LoRA model](https://huggingface.co/ClaireLee2429/gemma-2b-recipes-lora) deployed on HuggingFace Spaces.

### How SMS works

The agent sends recipes via SMS using this pipeline:

```
Agent (exec tool) --> sms.sh --> ClawdTalk API --> Telnyx API --> SMS delivered
```

ClawdTalk's `sms.sh` script authenticates with the ClawdTalk API key, which proxies the message to Telnyx for delivery. The agent asks the caller for their phone number since ClawdTalk does not pass caller ID to the agent during voice sessions.

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/glee2429/recipe-voice-agent.git
cd recipe-voice-agent

# 2. Export your API keys (add to ~/.zshrc or ~/.bashrc for persistence)
export ANTHROPIC_API_KEY=sk-ant-...   # from https://console.anthropic.com
export CLAWDTALK_API_KEY=cc_live_...  # from https://clawdtalk.com

# 3. Build and run
docker compose up --build -d

# 4. Verify
docker ps --filter name=recipe-voice-agent
docker logs recipe-voice-agent
```

> **Never paste API keys into an AI assistant chat.** Set them in your shell environment or a secrets manager, and let Docker Compose inherit them.

### Verifying the container

A healthy container should show:

```
[gateway] agent model: anthropic/claude-haiku-4-5
[gateway] listening on ws://127.0.0.1:18789
```

And the ClawdTalk log should show:

```
Connected, authenticating...
Authenticated (v1.2.9 agentic mode)
```

Check ClawdTalk connection:
```bash
docker exec recipe-voice-agent cat ~/.openclaw/skills/clawdtalk-client/.connect.log
```

## Configuration

| File | Purpose |
|------|---------|
| `config/openclaw.json` | Gateway config, tool permissions, skill entries |
| `workspace/AGENTS.md` | Agent identity and voice interaction rules |
| `workspace/SOUL.md` | Agent personality |
| `skills/recipe-generate/SKILL.md` | Recipe API integration and SMS workflow |
| `scripts/send-sms.sh` | SMS wrapper script for ClawdTalk |

### Tool permissions

The agent uses a **deny-list** approach for tool permissions in `openclaw.json`. All tools are available except those explicitly denied (write, edit, browser, message, etc.). The key tools the agent uses are:

- **exec** (bash): Runs `curl` for recipe generation and `sms.sh` for SMS sending
- **read**: Reads skill files to understand available tools
- **sessions_send**: Required by ClawdTalk at the gateway level for call routing

### Model selection

The agent model is configured in `config/openclaw.json` under `agents.defaults.model.primary`. Currently set to `anthropic/claude-haiku-4-5` for cost efficiency. For better multi-step tool-use reliability (at higher cost), change to:

```json
"primary": "anthropic/claude-sonnet-4-5"
```

Note: `console.anthropic.com` (API billing) is separate from `claude.ai` (chat subscription). Check your API credit balance at [console.anthropic.com](https://console.anthropic.com) under Plans & Billing.

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `ANTHROPIC_API_KEY` | Yes | Anthropic API key for the agent's LLM (from console.anthropic.com) |
| `CLAWDTALK_API_KEY` | Yes | ClawdTalk API key from clawdtalk.com |
| `RECIPE_LM_API_URL` | No | Defaults to `https://ClaireLee2429-recipe-lm-api.hf.space` |

`OPENCLAW_GATEWAY_TOKEN` is auto-generated at container startup. `CLAWDTALK_SERVER` defaults to `https://clawdtalk.com`.

### Secure key management

- **Always** set keys in your shell profile (`~/.zshrc` or `~/.bashrc`) and let Docker Compose inherit them
- **Never** commit keys to git or paste them into chat
- The `.env` file is gitignored as a safety net, but shell environment is preferred
- If a key is accidentally exposed, rotate it immediately at the provider's console

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Container crash-loops | Missing API keys | Export `ANTHROPIC_API_KEY` and `CLAWDTALK_API_KEY` in your shell |
| `credit balance is too low` | Anthropic API credits depleted | Add credits at console.anthropic.com |
| Recipe curl returns `(no output)` | SSE parsing mismatch | Ensure SKILL.md uses `jq -r '.full_text // empty'` not `grep` |
| `Unknown target for telegram` | Agent using wrong tool for SMS | Add `message` to the deny list in openclaw.json |
| `EACCES: permission denied, mkdir agents` | Volume mount ownership | Ensure `.openclaw/agents` is created in Dockerfile before volume mount |
| `sessions_send missing` warning | Gateway tools misconfigured | Add `"tools": {"allow": ["sessions_send"]}` under `gateway` in openclaw.json |
| SMS not delivered | Invalid phone number | Ensure E.164 format (+1 followed by 10 digits for US) |
| Agent says it will text but doesn't | Tool not available or Haiku skipping steps | Check deny list isn't blocking exec; consider upgrading to Sonnet |

## Related Projects

- [recipe-lm](https://github.com/glee2429/recipe-lm) - Training pipeline and inference server
- [kitchen-genie](https://github.com/glee2429/kitchen-genie) - React web frontend
