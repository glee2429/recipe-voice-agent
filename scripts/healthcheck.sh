#!/usr/bin/env bash
# Gateway is a WebSocket server; check that the port is accepting connections
curl -sf -o /dev/null --max-time 3 http://127.0.0.1:18789/ 2>/dev/null
# curl exit 52 (empty reply) means the server is up but speaking WebSocket, which is fine
[ $? -eq 0 ] || [ $? -eq 52 ] || exit 1
