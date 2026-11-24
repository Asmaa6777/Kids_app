#!/usr/bin/env bash
# Runs a command against the local Firebase emulators, e.g.:
#   ./emulate.sh "cd rules-tests && npm test"
#
# Some sandboxes inject Java options and HTTP proxies. They break the emulators'
# internal traffic (Storage rules → Firestore lookups), so they're removed here.
# On a normal computer or in GitHub Actions this changes nothing.
set -euo pipefail
cd "$(dirname "$0")"
ONLY="${EMULATORS:-auth,firestore,storage,functions}"
exec env -u JAVA_TOOL_OPTIONS -u _JAVA_OPTIONS \
  -u HTTPS_PROXY -u https_proxy -u HTTP_PROXY -u http_proxy -u GLOBAL_AGENT_HTTPS_PROXY \
  -u npm_config_https_proxy -u YARN_HTTPS_PROXY -u DOCKER_HTTPS_PROXY \
  firebase emulators:exec --only "$ONLY" "$1"
