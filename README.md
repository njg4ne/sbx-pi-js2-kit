# sbx-pi-js2-kit — Pi on Jetstream, in a Docker Sandbox

A [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) kit that runs the
[Pi](https://pi.dev) coding agent against **Jetstream Cloud (JS2)** inference,
through the Open Web UI proxy. The stock `docker.io/sbx/pi-kit` is wired for
llmman's Anthropic routing only; this kit reuses the same pre-baked
`docker.io/sbx/pi-image:latest` but gives Pi its own `js2` OpenAI-compatible
provider (`https://llm.jetstream-cloud.org/api`), with your key injected by
the sandbox proxy at egress — the key never exists inside the sandbox.
Published as `ghcr.io/njg4ne/sbx-pi-js2-kit`.

The commands below were tested with the `sbx` CLI **v0.50.1**; flags and
behavior can differ across versions, so if something fails, check
`sbx --version` first.

### Who this is for

Academics and researchers with a [Jetstream Cloud](https://www.jetstream-cloud.org/)
account — the NSF-funded (NSF ACCESS) research cyberinfrastructure at
Indiana University. With that login you can sign in to Jetstream Cloud's
[LLM inference service](https://docs.jetstream-cloud.org/inference-service/overview/)
Open Web UI and create an API key for its OpenAI-compatible API — **no
instance, allocation, or credits required** to use the inference service.
That API key is the only thing this kit needs (see
[the JS2 secret](#what-you-must-set-up-one-time-per-machine)).

## Run it

The two base forms. Always pass `--name`: without it the sandbox is named
`<agent>-<workdir>`, which is long and depends on where you stand. Short names
keep every follow-up command (`sbx run --name …`, `ssh …`, `sbx rm …`)
cheap to type. `pi` = kept around, `ephi` = ephemeral — a portmanteau
(blend) of *ephemeral* + *pi*. These are just suggestions: any short name
you like works, as long as you use it consistently.

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

Bound vs. mountless in one line each: **bound** mounts your cwd read-write at
the same absolute path — Pi edits your real files. **Mountless** mounts
nothing — Pi works in the sandbox's own filesystem; move files with
`sbx cp`.

## What you must set up (one-time, per machine)

1. **Docker Sandboxes installed and signed in** — the `sbx` CLI
   ([install](https://docs.docker.com/ai/sandboxes/install/)) plus
   `sbx login`.

2. **Allow this kit's GHCR source.** `kit.allowedSources` **replaces the
   entire list** (default `["docker.io/"]`) — write back what you want to
   keep:

   ```bash
   sbx settings set kit.allowedSources '["docker.io/","ghcr.io/njg4ne/"]'
   ```

   One-off without touching your settings — the same value is read from an
   environment variable:

   ```bash
   DOCKER_SANDBOXES_KIT_ALLOWED_SOURCES='["docker.io/","ghcr.io/njg4ne/"]' \
     sbx run --name pi ghcr.io/njg4ne/sbx-pi-js2-kit
   ```

   If a run fails with `source is not in your allowlist`, this is the step
   you're missing. See [kit sources](https://docs.docker.com/ai/sandboxes/configuration/settings/#kitallowedsources)
   for source formats.

3. **The JS2 secret.** Assumes you have access to Jetstream Cloud through the
   Open Web UI proxy and have created an API key in the Open Web UI settings:

   ```bash
   sbx secret set js2        # paste the key when prompted
   ```

That's the whole required list. Everything else is situation-dependent or
optional.

## Required in certain situations

- **Non-interactive/CI with no network preset set** — the CLI can't prompt
  for one, so set it first: `sbx policy init balanced` (or `allow-all` /
  `deny-all`). Interactively, you're prompted on first run — nothing to do.
- **Machine policy stricter than the kit's needs** — the kit already allows
  `llm.jetstream-cloud.org` and `registry.npmjs.org`, so a plain JS2 session
  works on any policy. If you want the agent to reach more, add per-sandbox
  rules ([network rules](https://docs.docker.com/ai/governance/local/network-rules/)):

  ```bash
  sbx policy allow network --sandbox pi github.com
  ```

  To give one sandbox *all* egress, use the bare `**` wildcard, which
  matches any host (tested on sbx v0.50.1):

  ```bash
  sbx policy allow network --sandbox pi "**"
  # ...later:
  sbx policy rm network --sandbox pi --resource "**"
  ```

  > **Danger.** This removes the network isolation for that sandbox: the agent
  > can reach any host — read and exfiltrate everything in its workspace,
  > download and run anything. Prefer the kit's allowlist or named hosts, and
  > only open `0.0.0.0/0` deliberately.
- **After changing the secret or the kit** — credential bindings and kit
  content are wired **at sandbox create time**; recreate the sandbox to pick
  up changes (`sbx rm pi && sbx run --name pi …`). Re-enter the key later
  with `sbx secret set -f js2`.

## Optional levers

- **SSH into any sandbox** (experimental):

  ```bash
  sbx setup ssh        # once; idempotent
  ssh pi.sbx           # keyless: daemon socket + your Docker login
  ```

- **A broad machine-wide network policy** — presets are `allow-all`,
  `balanced`, `deny-all`. Check what's active with `sbx policy ls` and
  `sbx policy check network llm.jetstream-cloud.org`; to change the preset you
  must reset first (deletes *all* local rules, stops running sandboxes):

  ```bash
  sbx policy reset --force && sbx policy init allow-all
  ```

- **`--model/--provider` model selection** (experimental) — **not needed for
  this kit**, which talks directly to JS2. Only if you also want llmman
  routing (local GGUF, Ollama, hosted providers):

  ```bash
  sbx settings set platform.allowExperimentalFeatures true
  sbx settings set feature.model true
  ```

  Experimental means it can change or disappear between releases; enabling it
  also starts the bundled `llmman` service, which downloads its runtime on
  first start (skip that with `sbx settings set model.server.enabled false &&
  sbx daemon restart`). See
  [Use local and hosted models](https://docs.docker.com/ai/sandboxes/configuration/models/).

## Things to know

- **A bound workspace is fully writable** — the agent can read, write, and
  delete anything under the mounted directory, including dotfiles and git
  hooks, and it has `sudo` plus a private Docker engine inside the VM. If you
  have doubts, run mountless or from a scratch directory.
  ([Default security posture](https://docs.docker.com/ai/sandboxes/security/defaults/))
- **Your JS2 key is never in the sandbox** — the agent sees a sentinel; the
  sandbox proxy swaps in the real credential only on egress to
  `llm.jetstream-cloud.org`. ([Credentials](https://docs.docker.com/ai/sandboxes/security/configuration/credentials/))
- **Mountless files die with the sandbox** — they persist across stop/restart
  but are deleted by `sbx rm`; copy anything you want out with `sbx cp` first.
- **`pi-image` rolls nightly** — it tracks the latest pi release, so a fresh
  sandbox boots the current pi; pinning the *kit* does not pin the *pi
  version*.

## Verify

Inside the sandbox:

```bash
pi auth check --provider js2 --credentials --json
```

or just ask it something: `pi -p "what version are you running"`.

## About these docs

Drafted by **Qwen 3.8 27B** running in the [pi](https://pi.dev) coding agent
(itself running inside a sandbox of this kit, over the js2 provider), in
back-and-forth with [@njg4ne](https://github.com/njg4ne), who oversaw,
reviewed, and tested the commands hands-on (the per-sandbox `**` egress
rule in particular). Still not rigorously tested as a whole — in
particular, the `DOCKER_SANDBOXES_KIT_ALLOWED_SOURCES` one-off was checked
against the Docker docs but not executed. Report problems to the
[kit repository](https://github.com/njg4ne/sbx-pi-js2-kit).

## Sources and references

Authoritative sources this kit draws on:

- [Docker Sandboxes documentation](https://docs.docker.com/ai/sandboxes/) —
  the `sbx` CLI, kits, credential injection, and network policy.
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
