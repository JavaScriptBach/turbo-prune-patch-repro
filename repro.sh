#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

TURBO_VERSION="${TURBO_VERSION:-2.11.5}"
export COREPACK_ENABLE_DOWNLOAD_PROMPT=0

echo "### 1. Full workspace install"
corepack yarn install --immutable > /dev/null
node packages/app/check.js

echo
echo "### 2. turbo@${TURBO_VERSION} prune app --docker"
rm -rf out
npx -y "turbo@${TURBO_VERSION}" prune app --docker > /dev/null
echo "root resolutions:   $(node -p 'JSON.stringify(require("./package.json").resolutions)')"
echo "pruned resolutions: $(node -p 'JSON.stringify(require("./out/json/package.json").resolutions)')"
echo "pruned .yarn/patches: $(ls out/json/.yarn/patches 2>/dev/null || echo '(missing)')"
echo "debug entries in pruned yarn.lock:"
grep '^"debug@' out/yarn.lock | sed 's/^/  /'

echo
echo "### 3. Install from pruned output (out/json)"
cd out/json
if corepack yarn install --immutable > /dev/null 2>&1; then
  echo "yarn install --immutable: succeeded"
else
  echo "yarn install --immutable: FAILED (pruned yarn.lock is not consistent with pruned package.json files)"
fi
corepack yarn install > /dev/null
echo "yarn install (non-immutable):"
node -e '
  const debug = require(require.resolve("debug", { paths: ["packages/app"] }));
  console.log(`  debug@${require(require.resolve("debug/package.json", { paths: ["packages/app"] })).version} patched: ${debug.patchedByRepro === true}`);
'
