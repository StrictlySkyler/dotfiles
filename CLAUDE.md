# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Environment Overview

This is Skyler Forge's home directory on a Linux workstation (Pop!_OS/Ubuntu-based). It is **not** a single git repository — individual projects live in `~/src/` and services configuration lives in `~/services/`.

- **Shell**: bash with oh-my-bash (powerline-multiline theme)
- **Node**: managed via nvm (`~/.nvm`)
- **Flutter/Dart**: managed via fvm (`~/fvm/bin`), project pin via `.fvmrc`
- **Python**: `/home/linuxbrew/.linuxbrew/bin/python3` (aliased as `python`)
- **Editor**: vim (`.vimrc` configured), Cursor IDE also used
- **Git**: diff/merge tool is kdiff3; user is `Skyler Forge <strictlyskyler@gmail.com>`
- **Aliases**: `_` = sudo, `vi` = vim, `astudio` = Android Studio

## Key Projects (`~/src/`)

### harbormaster-io / harbormaster-public
Meteor.js + Vue 3 app with MongoDB backend. CI/CD pipeline management tool.
- **Run**: `npm run start` (Meteor dev server)
- **Test**: `npm test` (Mocha, single run) or `npm run test:watch`
- **Lint**: `npm run lint` (working tree only), `npm run lint:all`
- **E2E**: `npm run test:e2e` (Cypress, starts server automatically)
- **E2E interactive**: `npm run test:e2e:watch`
- **Coverage**: `npm run coverage`
- **Reset**: `npm run reset`
- Test port defaults to 4040; E2E server runs on port 4042.
- Two repos exist: `harbormaster-io` (private) and `harbormaster-public` (open source). Same codebase structure.
- Code is organized under `imports/` with `api/`, `ui/`, `startup/`, `entrypoints/`, `e2e-tests/`, and `test-helpers/`.

### bittyblinky
Flutter app — LED animation controller for a hardware product (BittyBlinky).
- **Run**: `flutter run` (or via fvm: `fvm flutter run`)
- **Test**: `flutter test`
- **Analyze**: `flutter analyze` (uses `analysis_options.yaml`)
- Targets: Android, iOS, Linux, macOS, Windows, Web
- `on_device/mk_I/` contains CircuitPython code (`code.py`) and animation assets for the physical hardware (Feather S3)
- `lib/` structure: `constants/`, `models/`, `pages/`, `platform/`, `services/`, `utils/`, `widgets/`
- Uses Flutter SDK `^3.9.0` pinned via `.fvmrc`

### cinf (C-Infinity)
Python scientific/engineering application with a Node.js UI layer. Multiple forks exist in `~/src/cinf/` — the active ones are `cinf-org` and `strictlyskyler-cinf`.
- **Run**: `./run.sh` or via Docker: `docker-compose up`
- **Test (Python)**: `pytest` (config in `pytest.ini`)
- **Test (UI)**: vitest (results in `vitest-results.xml`)
- **Lint (Python)**: pylint (config in `.pylintrc`)
- Dockerized development workflow; `entrypoint.sh` for dev, `entrypoint.prod.sh` for production
- Has conda environment config (`environment.yml`)
- Infrastructure: ECS deployment (`deploy/`), secrets managed with sops (`.sops.yaml`)

## Services (`~/services/`)

Self-hosted infrastructure managed with **podman-compose** (rootless Podman), deployed to a server called **orphic-lens** (Bazzite/Fedora Atomic).

- **Start all**: `podman-compose up -d` then `./start.sh` (health-checks all services)
- **Cert renewal**: handled by systemd timer (`certbot-renew.timer`)
- **Auto-start on boot**: `skyler-services.service` systemd user unit

Services hosted:
- **harbormaster.skyler.is** / **demo.harbormaster.io** — Harbormaster instances (Meteor/Node)
- **skyler.is** / **harbormaster.io** — WordPress sites (MySQL backends)
- **where.skyler.is** — daemon-event-collector + daemon-map (location tracking)
- **pota.skyler.is** — FoundryVTT (tabletop RPG)
- **Icecast** on port 8000 (audio streaming)
- **harbor-cat** — AI assistant service (uses Ollama)
- **stereofypical** — Meteor app
- **nginx** — reverse proxy with SSL termination (Let's Encrypt via Cloudflare DNS challenge)
- **MongoDB 5** and **MySQL 5.7/8.3** databases

DNS: `skyler.is` subdomains CNAME to `demonweave.asuscomm.com` (ASUS DDNS for dynamic IP). See `CUTOVER.md` for the full migration plan from GCP.

## Utilities

- `~/remote_sync.sh` — rsync data from remote server via tmux session on orphic-lens
- `~/bin/oh-my-posh` — prompt theme engine
- `~/bin/spacemouse.sh` — 3D mouse support script
