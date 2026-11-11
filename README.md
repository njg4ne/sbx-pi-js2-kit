# sbx-pi-js2-kit

A [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) kit that runs the
[Pi](https://pi.dev) coding agent against **Jetstream Cloud (JS2)** inference,
through the Open Web UI proxy.

Pi reads its model providers from its own `~/.pi/agent/models.json`, so this
kit does not depend on Docker's bundled `llmman` router (which the stock
`docker.io/sbx/pi-kit` is wired for, Anthropic only). Instead, this kit:

- reuses the pre-baked `docker.io/sbx/pi-image:latest` base image,
- injects your JS2 API key into the sandbox as a proxy-managed credential
  (header `Authorization: Bearer <key>` for `llm.jetstream-cloud.org` — the key
  never appears in the sandbox filesystem or environment),
- ships `~/.pi/agent/models.json` defining a `js2` OpenAI-compatible provider
  pointing at `https://llm.jetstream-cloud.org/api`, with the API key resolved
  from the injected `JS2_API_KEY` env var at runtime.

Published as an OCI kit reference: `ghcr.io/njg4ne/sbx-pi-js2-kit`.

## Quick start

### Prerequisites

1. **Docker Sandboxes installed and signed in** — the `sbx` CLI from
   [Docker Sandboxes: Install](https://docs.docker.com/ai/sandboxes/install/).
2. **Allow the GHCR source for this kit.** Docker Sandboxes only installs kits
   from allowlisted sources; this kit lives on GHCR. Run once:

   ```bash
   sbx settings set kit.allowedSources '["docker.io/","dhi.io/","ghcr.io/njg4ne/"]'
   ```

   If you get an error about `kit.allowedSources` when running the commands
   below, this is the step you're missing.
3. **A JS2 API key.** This assumes you have access to Jetstream Cloud through
   the Open Web UI proxy and have created an API key in the Open Web UI
   settings. Store it as the `js2` sandbox secret, run once:

   ```bash
   sbx secret set js2
   ```

   and paste the key when prompted. If you need to change it later:
   `sbx secret set -f js2`.

After any secret or kit change, recreate the sandbox — credentials and
bindings are wired at create time.

### Run it

Pick the flavor you want. Two axes:

- **Workspace**: current directory bound into the sandbox (Pi works on your
  files) vs. mountless (Pi works in the sandbox's own
  `/home/agent/workspace`, nothing on your machine is touched).
- **Lifetime**: `--rm` (ephemeral — sandbox is deleted when the session
  exits) vs. kept (sandbox persists so you can re-attach or `sbx exec` later).

Sandbox names are short on purpose: `ephi` = ephemeral pi, `pi` = kept pi.

#### 1. Current directory bound, ephemeral (default choice)

```bash
sbx run --rm --name ephi ghcr.io/njg4ne/sbx-pi-js2-kit
```

Pi opens in your current directory; when you exit, the sandbox and all of its
files are gone.

#### 2. Current directory bound, persistent

```bash
sbx run --name pi ghcr.io/njg4ne/sbx-pi-js2-kit
```

Same as above but the sandbox sticks around after you exit. Re-attach from any
directory with:

```bash
sbx run --name pi
```

Remove it when you're done: `sbx rm pi`.

#### 3. No host files bound, ephemeral

```bash
sbx create --name ephi ghcr.io/njg4ne/sbx-pi-js2-kit
sbx run --rm --name ephi
```

`sbx create` without a path makes a mountless sandbox — useful for trying
things out without binding any files. Files Pi creates live in
`/home/agent/workspace` inside the sandbox; copy them out with `sbx cp` before
the session ends.

#### 4. No host files bound, persistent

```bash
sbx create --name pi ghcr.io/njg4ne/sbx-pi-js2-kit
sbx run --name pi
```

Mountless sandbox that survives between sessions. Re-attach with
`sbx run --name pi`; delete with `sbx rm pi`.

### Verify it works

Inside the sandbox:

```bash
pi auth check --provider js2 --credentials --json
```

or just ask it something: `pi -p "what version are you running"`.

## Kit layout

```
spec.yaml                        # v2 sandbox kit spec (image, credentials, entrypoint)
files/home/.pi/agent/models.json # Pi provider "js2" (OpenAI-compatible, JS2 base URL)
files/home/.pi/agent/settings.json
```

`spec.yaml` declares the `js2` credential service with `proxyManaged: true` and
an inject rule that adds the `Authorization` header on requests to
`llm.jetstream-cloud.org`. `models.json` references `$JS2_API_KEY`, which Pi
resolves from the environment the proxy injects — the key itself is never
written into the sandbox.

## Rebuild / republish

From a checkout of the parent repo (which contains this kit and a `push.sh` helper):

```bash
./push.sh            # pushes ghcr.io/njg4ne/sbx-pi-js2-kit:latest
./push.sh v1         # pushes a tagged version
./push.sh -r         # also re-prompts for the GHCR registry secret
```
