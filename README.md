# `turbo prune` drops Yarn Berry patch resolutions for direct workspace dependencies

`turbo prune` drops a root `resolutions` entry that points at a `patch:` protocol when:

- the key is a descriptor with a range (`debug@npm:^4.0.0`), and
- the patched package is a direct dependency of a workspace in the pruned graph.

The pruned output also leaves out the patch file and the `patch:` lockfile entry. A `yarn install` from the pruned output completes and installs the **unpatched** package. Nothing in the output warns that the patch was lost.

## Versions

- turbo 2.11.5 (latest at time of writing). Also reproduced on 2.9.16.
- Yarn 4.18.1, `nodeLinker: node-modules`
- Node 22

## Setup

- `packages/app` depends on `debug@^4.0.0`, which resolves to 4.4.3.
- The root `package.json` patches it through `resolutions`, which is the shape `yarn patch-commit -s` produces for a range dependency:

  ```json
  "resolutions": {
    "debug@npm:^4.0.0": "patch:debug@npm%3A4.4.3#~/.yarn/patches/debug-npm-4.4.3.patch"
  }
  ```

- The patch adds `module.exports.patchedByRepro = true;` to `debug`, so it's easy to see whether it was applied.

## Reproduce

```bash
./repro.sh
```

To test another turbo version:

```bash
TURBO_VERSION=2.9.16 ./repro.sh
```

## Output

```
### 1. Full workspace install
debug@4.4.3 patched: true

### 2. turbo@2.11.5 prune app --docker
root resolutions:   {"debug@npm:^4.0.0":"patch:debug@npm%3A4.4.3#~/.yarn/patches/debug-npm-4.4.3.patch"}
pruned resolutions: {}
pruned .yarn/patches: (missing)
debug entries in pruned yarn.lock:
  "debug@npm:4.4.3":

### 3. Install from pruned output (out/json)
yarn install --immutable: FAILED (pruned yarn.lock is not consistent with pruned package.json files)
yarn install (non-immutable):
  debug@4.4.3 patched: false
```

## Expected

- `out/json/package.json` and `out/full/package.json` keep the `debug@npm:^4.0.0` resolution.
- `out/json/.yarn/patches/debug-npm-4.4.3.patch` is present.
- `out/yarn.lock` keeps the `debug@patch:...` entry.
- An install from the pruned output installs the patched `debug`.

## Actual

- The resolution is removed from the pruned `package.json` files.
- The patch file is not copied.
- The pruned lockfile only has the unpatched `debug@npm:4.4.3` entry.
- A non-immutable `yarn install` from `out/json` installs unpatched `debug` without any error.

The pruned lockfile also drops `debug`'s own dependency, `ms@npm:^2.1.3`, so `yarn install --immutable` fails here. In a larger monorepo where that dependency is reachable another way, the pruned lockfile can be consistent. Then even `--immutable` succeeds and installs the unpatched package with no signal at all.

## Variants tested (turbo 2.11.5)

| Workspace dependency | Resolution key | Kept by prune? |
|---|---|---|
| `debug@^4.0.0` | `debug@npm:^4.0.0` | **No** |
| `debug@^4.4.3` | `debug@npm:^4.4.3` | **No** |
| `debug@^4.0.0` | `debug` (bare name) | Yes |
| `debug@4.4.3` | `debug@npm:4.4.3` | Yes |
| (transitive) `ms` via `debug` | `ms@npm:^2.1.3` | Yes |
| (transitive) `ms` via `debug`, with `debug@npm:^4.0.0` also patched | `ms@npm:^2.1.3` | **No**, dropped along with `debug` |
