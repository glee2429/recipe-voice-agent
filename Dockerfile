FROM node:22-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl jq git bash ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Non-root user
RUN useradd -m -u 1000 -s /bin/bash clawuser
USER clawuser
WORKDIR /home/clawuser

# Install OpenClaw
RUN npm install -g openclaw@latest

# Create directory structure
RUN mkdir -p .openclaw/skills .openclaw/workspace

# Copy configuration
COPY --chown=clawuser:clawuser config/openclaw.json .openclaw/openclaw.json
COPY --chown=clawuser:clawuser workspace/ .openclaw/workspace/
COPY --chown=clawuser:clawuser skills/ .openclaw/skills/

# Install ClawdTalk client
RUN git clone https://github.com/team-telnyx/clawdtalk-client.git \
    .openclaw/skills/clawdtalk-client \
    && cd .openclaw/skills/clawdtalk-client \
    && npm install --production 2>/dev/null || true

# Copy entrypoint and scripts
COPY --chown=clawuser:clawuser entrypoint.sh /home/clawuser/entrypoint.sh
COPY --chown=clawuser:clawuser scripts/ /home/clawuser/scripts/
RUN chmod +x /home/clawuser/entrypoint.sh /home/clawuser/scripts/*.sh

# Gateway port (loopback only in prod, exposed for dev/debugging)
EXPOSE 18789

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD /home/clawuser/scripts/healthcheck.sh

ENTRYPOINT ["/home/clawuser/entrypoint.sh"]
