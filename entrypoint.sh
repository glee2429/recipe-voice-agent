#!/usr/bin/env bash
set -euo pipefail

echo "=== recipe-voice-agent starting ==="

# ---- Validate required environment variables ----
required_vars=(
    "ANTHROPIC_API_KEY"
    "CLAWDTALK_API_KEY"
)
for var in "${required_vars[@]}"; do
    if [ -z "${!var:-}" ]; then
        echo "ERROR: Required environment variable $var is not set"
        echo "Copy .env.example to .env and fill in your keys."
        exit 1
    fi
done

# ---- Auto-generate gateway token if not provided ----
if [ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]; then
    export OPENCLAW_GATEWAY_TOKEN=$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')
    echo "Generated OPENCLAW_GATEWAY_TOKEN (not set externally)."
fi

# ---- Generate ClawdTalk skill-config.json from env vars ----
# Written at runtime so secrets never end up in Docker image layers
cat > ~/.openclaw/skills/clawdtalk-client/skill-config.json <<EOF
{
    "api_key": "${CLAWDTALK_API_KEY}",
    "server": "${CLAWDTALK_SERVER:-https://clawdtalk.com}",
    "greeting": "Thanks for calling Kitchen Genie! I'm here to help you explore new recipes. What would you like to cook today?"
}
EOF

echo "ClawdTalk config written."

# ---- Start ClawdTalk WebSocket client (background) ----
echo "Starting ClawdTalk WebSocket client..."
cd ~/.openclaw/skills/clawdtalk-client
./scripts/connect.sh start &
CLAWDTALK_PID=$!
echo "ClawdTalk started (PID $CLAWDTALK_PID)"
cd ~

# ---- Start OpenClaw gateway (foreground, becomes PID 1) ----
echo "Starting OpenClaw gateway on port 18789..."
exec openclaw gateway --port 18789 --verbose
