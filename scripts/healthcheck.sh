#!/usr/bin/env bash
curl -sf http://127.0.0.1:18789/health > /dev/null 2>&1 || exit 1
