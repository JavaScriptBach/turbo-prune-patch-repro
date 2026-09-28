const debug = require("debug");
console.log(`debug@${require("debug/package.json").version} patched: ${debug.patchedByRepro === true}`);
