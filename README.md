# Lightweight OpenCode on Railway

A small, separate OpenCode 2 coding-worker service for testing alongside an
existing Hermes service. No Hermes configuration is changed by this repository.

Includes OpenCode **2.0.32**, Node.js 24/npm, Git, curl, SSH client and ripgrep.
It intentionally leaves out Chromium, browser automation, Python, Go, Bun, mise,
the GitHub CLI and Railway CLI. Model inference happens at your chosen provider;
this image does not download model weights.

## 1. Deploy in Railway

1. Open the **same project and environment as Hermes**.
2. Choose **New → GitHub Repo** and select this repository.
3. Name the new service `opencode`. Railway reads `railway.json` and builds the
   Dockerfile. Leave custom Build and Start commands empty.
4. Attach a persistent volume mounted at **`/data`**. The volume is not created
   automatically by this repository.
5. Add these service variables:

   | Variable | Value |
   | --- | --- |
   | `OPENCODE_PASSWORD` | A unique long random password; enter privately |
   | `PORT` | `4096` |

6. Deploy. Keep Serverless sleeping disabled while testing continuous tasks.
7. If you need browser/laptop access, generate a public domain with target port
   **4096**. Do not expose the service without authentication.

The startup script refuses to launch without a password. OpenCode handles
authentication using the username `opencode`. Work runs as an unprivileged user;
root is used only to prepare the mounted directories at startup.

Do not commit API keys, passwords, GitHub tokens or database credentials. Review
and redact logs before sharing them: upstream software may include sensitive
connection details in its startup output.

## 2. Connect and choose a model

Install the matching **OpenCode 2** client on your laptop:

```sh
npm install -g @opencode/cli@2.0.32
opencode --server https://YOUR-SERVICE.up.railway.app
```

Authenticate privately when requested. OpenCode 1 uses different client commands;
do not mix the versions. You can also open the service domain in a browser.

In the connected OpenCode terminal, run `/connect`, select **OpenCode Go**, and
provide your key privately. Use `/models` to select your approved model. Provider
credentials and sessions are kept beneath `/data/home`. Keep paid balance fallback
and automatic top-ups disabled in the provider account if you do not want overage.

Begin with one tiny request that does not edit files, such as asking OpenCode to
explain what tools it has. Do not start by installing all project dependencies.

## 3. Persistence and trial limits

| Path | Purpose |
| --- | --- |
| `/data/home` | OpenCode home, settings, sessions, credentials and cache |
| `/data/workspace` | Project clones and working files |
| `/tmp/npm-cache` | Disposable npm cache; not preserved on redeploy |

Always mount the volume at `/data`; otherwise files will be lost on redeploy.
Back up needed work before deleting the service or volume. A volume is not an
off-server backup.

Railway's documented Trial limits are **4 GB image**, **0.5 GB volume**, **1 GB
RAM**, and **1 GB ephemeral storage** per service. Check your own dashboard because
plan limits can change. A smaller image does not increase the volume or RAM limit.
PromisePlanner dependency installs, build output and multiple worktrees may exceed
these trial limits even if the initial OpenCode connection works.

Full project builds and browser testing are **not promised** on the trial. First
verify connection and one request, then measure actual disk/RAM use before adding
more work. Hosting credits and model-provider usage are separate costs.

## 4. Hermes and Herdr connections

Within the same Railway project/environment, Hermes can reach this service at:

```text
http://opencode.railway.internal:4096
```

Use the actual Railway private domain if the service name is different. Keep
authentication enabled even on the private network. Give Hermes the URL and
password through private configuration, not a GitHub issue or committed file.

Deploying this repository does **not** install a Hermes skill or implement task
delegation. A version-matched authenticated API client/bridge must still be
configured and tested. OpenCode 2's API differs from OpenCode 1.

Herdr is not installed in this image. Initially, a local Herdr terminal can run
the OpenCode 2 client connected to the remote server. Full Herdr status integration
with attached remote clients remains to be tested.

## 5. PromisePlanner safety rules

- Start with one worker and one task at a time.
- Read the repository's `AGENTS.md`, `PROJECT.md`, then `docs/README.md`.
- Use an individual feature branch/worktree. Never push directly to `dev` or
  `main`. Open a PR targeting `dev`; the human approves and performs merges.
- Do not give the worker production database credentials or a Railway deployment
  token. Use isolated test data only.
- Repository instructions are not a security boundary. Enforce access restrictions
  with GitHub permissions and branch rules as well.
- Ask before switching to a more expensive model. No automatic paid fallback or
  top-ups. Pause if no approved model is available.

GitHub write access and cloning a private project are separate steps: this image
does not automatically clone PromisePlanner, receive a token or open PRs.

## Verification

Locally verified on Linux amd64 using Podman, 19 October 2026:

- Container build and OpenCode 2.0.32 version check: passed.
- Local uncompressed image size: **1,211,458,559 bytes (about 1.21 GB)**, below the
  documented 4 GB Trial image limit. A future base-image update can change size.
- Startup rejects a missing password and invalid port: passed.
- Authenticated API access and rejection of unauthenticated access: passed.
- OpenCode's own home/data paths resolve under `/data/home`: passed. The account's
  home directory is explicitly set because `gosu` resets `HOME` when switching users.
- A real empty OpenCode session and files survive container replacement on the
  same volume: passed.
- Smoke-test containers use a 1 GB memory limit and 2 CPU limit. This proves basic
  startup, not capacity for actual coding/build workloads.

Reproduce the tests (Docker):

```sh
docker build -t opencode-railway-lite:check .
sh test/smoke.sh opencode-railway-lite:check
```

For Podman, replace the build command's `docker` with `podman` and prefix the test
command with `CONTAINER_ENGINE=podman`. Tests create disposable containers/volumes
and remove those test resources afterward. No model request is made.

Not yet verified: Railway deployment/routing, a real model request, OpenCode Go
credentials, GitHub write access, full PromisePlanner builds, Hermes delegation,
or Herdr's remote-session status integration. No Railway deployment has been
performed by creating these files.

## References

- [OpenCode 2 installation](https://opencode.ai/v2/docs/)
- [Foreground server and remote access](https://opencode.ai/v2/docs/cli/web/)
- [OpenCode 2 client](https://opencode.ai/v2/docs/cli/)
- [OpenCode Go](https://opencode.ai/v2/docs/console/go/)
- [Railway plan limits](https://docs.railway.com/pricing/plans)
- [Railway private networking](https://docs.railway.com/networking/private-networking)
