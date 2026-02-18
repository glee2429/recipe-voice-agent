FROM node:22-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl jq git bash ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install OpenClaw globally (requires root for /usr/local/lib)
RUN npm install -g openclaw@latest

# Switch to non-root 'node' user (uid 1000, provided by base image)
USER node
WORKDIR /home/node

# Create directory structure
RUN mkdir -p .openclaw/skills .openclaw/workspace

# Copy configuration
COPY --chown=node:node config/openclaw.json .openclaw/openclaw.json
COPY --chown=node:node workspace/ .openclaw/workspace/
COPY --chown=node:node skills/ .openclaw/skills/

# Install ClawdTalk client
RUN git clone https://github.com/team-telnyx/clawdtalk-client.git \
    .openclaw/skills/clawdtalk-client \
    && cd .openclaw/skills/clawdtalk-client \
    && npm install --production 2>/dev/null || true

# Copy entrypoint and scripts
COPY --chown=node:node entrypoint.sh /home/node/entrypoint.sh
COPY --chown=node:node scripts/ /home/node/scripts/
RUN chmod +x /home/node/entrypoint.sh /home/node/scripts/*.sh

# Gateway port (loopback only in prod, exposed for dev/debugging)
EXPOSE 18789

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD /home/node/scripts/healthcheck.sh

ENTRYPOINT ["/home/node/entrypoint.sh"]
