#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
# Compatibility entry point: characters now share a single application.
zsh scripts/build-app.sh
echo "치이카와와 하치와레는 dist/ChiikawaDesk.app 하나에서 함께 실행됩니다."
