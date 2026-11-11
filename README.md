# sbx-pi-js2-kit

A [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) kit that runs the
[Pi](https://pi.dev) coding agent against **Jetstream Cloud (JS2)** inference,
through the Open Web UI proxy. The stock `docker.io/sbx/pi-kit` is wired for
llmman's Anthropic routing only; this kit reuses the same pre-baked
`docker.io/sbx/pi-image:latest` but gives Pi its own `js2` OpenAI-compatible
provider (`https://llm.jetstream-cloud.org/api`), with your key injected by the
sandbox proxy as a `Bearer` header — the key never touches the sandbox
filesystem. Published as `ghcr.io/njg4ne/sbx-pi-js2-kit`.

The commands below were tested with the `sbx` CLI **v0.50.1**; flags and
behavior can differ across versions, so if something fails, check
`sbx --version` first.

## Run it

The two base forms. Always pass `--name`: without it the sandbox is named
`<agent>-<workdir>`, which is long and depends on where you stand. Short names
keep every follow-up command (`sbx run --name …`, `ssh …`, `sbx rm …`)
cheap to type. `pi` = kept around, `ephi` = ephemeral.

```bash
# One command: binds your current directory, attaches to Pi
sbx run --name pi ghcr.io/njg4ne/sbx-pi-js2-kit

# Create, then run: same thing in two steps (create with no attach,
# attach whenever you like)
sbx create --name pi ghcr.io/njg4ne/sbx-pi-js2-kit .
sbx run --name pi
```

### Variations (combine freely)

- **Ephemeral** — add `--rm` to the *run* so the sandbox is deleted when the
  session exits; rename to `ephi` to match:

  ```bash
  sbx run --rm --name ephi ghcr.io/njg4ne/sbx-pi-js2-kit
  ```

- **Without your current directory** — omit the path at *create* time; the
  sandbox is mountless and Pi works in its own `/home/agent/workspace`:

  ```bash
  sbx create --name ephi ghcr.io/njg4ne/sbx-pi-js2-kit
  sbx run --rm --name ephi
  ```

- **Re-attach from anywhere** — a named sandbox re-attaches from any working
  directory; no agent or path needed:

  ```bash
  sbx run --name pi
  ```

- **Tear down** — `sbx rm pi` (or `sbx rm ephi`).

- **Open egress for just this sandbox** — the kit only allows
  `llm.jetstream-cloud.org` and `registry.npmjs.org`. If your machine policy is
  strict and you want this one sandbox to reach anything (arbitrary npm
  packages, GitHub, …), add a rule scoped to the sandbox rather than widening
  your global policy. There is no `*` host pattern; the all-traffic equivalent
  is the CIDR `0.0.0.0/0`:

  ```bash
  sbx policy allow network --sandbox pi 0.0.0.0/0
  # ...later:
  sbx policy rm network --sandbox pi --resource 0.0.0.0/0
  ```

  > **Danger.** This removes the network isolation for that sandbox: the agent
  > can reach any host on the internet — read and exfiltrate everything in its
  > workspace, download and run anything. The whole point of the sandbox is
  > least-privilege egress. Prefer the kit's own allowlist (or a deny-all
  > policy plus named hosts) and only open `0.0.0.0/0` deliberately.

### With or without your current directory

- **Bound** (`sbx run <kit>` or `sbx create <kit> .`): your cwd is mounted
  read-write at the same absolute path inside the sandbox. Pi edits your real
  files; host and sandbox see the same tree.
- **Mountless** (`sbx create <kit>` with no path): nothing from your machine is
  mounted. Pi works in `/home/agent/workspace` inside the sandbox; files there
  persist across stop/restart and die with the sandbox. Copy things in and out
  with `sbx cp`.

## Prerequisites (one-time, per machine)

1. **Docker Sandboxes installed and signed in** — the `sbx` CLI from
   [Install](https://docs.docker.com/ai/sandboxes/install/), plus
   `sbx login` (v0.50.1 or later recommended).

2. **Allow this kit's GHCR source — without clobbering your defaults.**
   `kit.allowedSources` **replaces the entire list** (the default is
   `["docker.io/"]`), so write back whatever you want to keep:

   ```bash
   sbx settings set kit.allowedSources '["docker.io/","ghcr.io/njg4ne/"]'
   ```

   One-off, without touching your settings at all — the same value is read
   from an environment variable, so a single command can carry it:

   ```bash
   DOCKER_SANDBOXES_KIT_ALLOWED_SOURCES='["docker.io/","ghcr.io/njg4ne/"]' \
     sbx run --name pi ghcr.io/njg4ne/sbx-pi-js2-kit
   ```

   If a run fails with `kit "…": source is not in your allowlist`, this is the
   step you're missing.

### Provider configuration

3. **The JS2 secret.** Assumes you have access to Jetstream Cloud through the
   Open Web UI proxy and have created an API key in the Open Web UI settings.
   Store it once:

   ```bash
   sbx secret set js2        # paste the key when prompted
   ```

   Credential bindings are wired **at sandbox create time** — after changing
   the secret (or the kit), recreate the sandbox (`sbx rm pi && sbx run --name
   pi …`). Re-enter later with `sbx secret set -f js2`.

4. **Model selection flags (optional for this kit).** If you also want
   `sbx run --model/--provider` (llmman routing: local GGUF models, host
   Ollama, hosted providers):

   ```bash
   sbx settings set platform.allowExperimentalFeatures true
   sbx settings set feature.model true
   ```

   *Purpose:* these two settings switch on the experimental `--model`/
   `--provider` flags backed by the bundled `llmman` model service.
   *Safety:* they are experimental — behavior can change or be removed between
   releases without warning — and enabling the model feature starts `llmman`
   with the daemon, which downloads its llama.cpp runtime on first start.
   This kit does **not** need them: it talks directly to JS2 through its own
   provider config. If you don't use `--model`, turn the bundled service off
   to skip the runtime download:
   `sbx settings set model.server.enabled false && sbx daemon restart`.

## General Docker Sandboxes setup

These are one-time, machine-wide conveniences that also apply to this
sandbox.

### SSH into any sandbox

```bash
sbx setup ssh        # once; idempotent, safe to re-run
ssh pi.sbx           # now works, no prompts, no client key
```

Experimental. Writes a generated SSH config + `known_hosts` and includes it
from `~/.ssh/config`; authentication goes through the daemon's local socket
plus your Docker login (`sbx login` first), so no SSH key is needed. Works for
every sandbox you run, this one included. Remove with `sbx setup ssh remove`.

### Reset or widen the network policy

Check what's active first:

```bash
sbx policy ls
sbx policy check network llm.jetstream-cloud.org
```

If you want a broad policy (or you reset a strict one), the presets are
`allow-all`, `balanced`, and `deny-all`. `sbx policy init` only works before a
preset exists, so to change it you must reset first:

```bash
sbx policy reset                              # wipes ALL local rules, restarts
                                              # the daemon, prompts for preset
sbx policy reset --force                      # same, no confirmation
sbx policy init allow-all                     # or balanced / deny-all
```

> **Warning:** `sbx policy reset` deletes every locally configured rule —
> including destinations you individually approved — and running sandboxes
> stop when the daemon restarts. Non-interactive form:
> `sbx --no-input policy reset --force && sbx policy init allow-all`.

### Verify the kit works

Inside the sandbox:

```bash
pi auth check --provider js2 --credentials --json
```

or just ask it something: `pi -p "what version are you running"`.

## Sources and references

Authoritative sources this kit draws on:

- [Docker Sandboxes documentation](https://docs.docker.com/ai/sandboxes/) —
  the `sbx` CLI, kits, credential injection, and network policy. Specific
  pages cited above: [usage](https://docs.docker.com/ai/sandboxes/usage/),
  [network rules](https://docs.docker.com/ai/governance/local/network-rules/),
  [default security posture](https://docs.docker.com/ai/sandboxes/security/defaults/),
  [kit sources](https://docs.docker.com/ai/sandboxes/configuration/settings/#kitallowedsources).
- [docker/sbx-kits-contrib](https://github.com/docker/sbx-kits-contrib) — the
  official Docker sandbox kits, including the
  [official Pi kit](https://github.com/docker/sbx-kits-contrib/tree/main/pi)
  that this kit inherits from: we reuse its pre-baked
  `docker.io/sbx/pi-image:latest` base image and follow its spec conventions
  (explicit egress allowlist, proxy-managed credential injection, bundled
  agent config under `files/`). The `pi/` directory there (Dockerfile,
  spec.yaml, READMEs) is the reference implementation for how a Pi sandbox
  kit is built and why each piece exists.
- [Jetstream Cloud documentation](https://docs.jetstream-cloud.org/) — the
  inference service this kit targets, including the
  [inference service overview](https://docs.jetstream-cloud.org/inference-service/overview/)
  (access through the Open Web UI proxy, API keys).
- [Pi (pi-coding-agent)](https://pi.dev) — the coding agent itself
  ([npm](https://www.npmjs.com/package/@earendil-works/pi-coding-agent)); its
  `models.json`/`settings.json` provider config is what this kit supplies.
- [llmman](https://github.com/llmmanorg/llmman) — Docker Sandboxes' bundled
  model router, referenced for context on `--model/--provider` and its Pi
  integration.
