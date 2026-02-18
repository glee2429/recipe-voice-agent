#!/bin/bash
# Send an SMS via ClawdTalk
# Usage: send-sms.sh +1XXXXXXXXXX "message text"
set -euo pipefail
~/.openclaw/skills/clawdtalk-client/scripts/sms.sh send "$1" "$2"
