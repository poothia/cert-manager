#!/usr/bin/env bash
# Cleanup: remove everything created by this demo
set -euo pipefail

echo "Cleaning up custom-domain-demo..."
oc delete project custom-domain-demo --wait=false 2>/dev/null || true
echo "Done. Namespace deletion will complete in the background."
