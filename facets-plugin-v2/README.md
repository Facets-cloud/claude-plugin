# Facets Cloud v2 — Headless Infrastructure Co-Pilot

Talk to your infrastructure in plain English. No CLI knowledge needed, no platform internals exposed. Design, deploy, inspect, troubleshoot, and build modules — all through natural language.

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- [Raptor CLI](https://github.com/Facets-cloud/raptor-releases) installed and authenticated
- Terraform >= 1.5.0 (for module development)

### Install Raptor CLI

Follow the installation instructions at [Facets-cloud/raptor-releases](https://github.com/Facets-cloud/raptor-releases), then authenticate:

```bash
raptor login
raptor whoami
```

## Installation

```bash
# Add the marketplace (one-time setup)
/plugin marketplace add Facets-cloud/claude-plugin

# Install the plugin
/plugin install facets-plugin-v2@facets-marketplace
```

## How It Works

```
  "I need a SaaS app with Postgres and Redis"
                    │
                    ▼
  ┌─────────────────────────────────┐
  │         /facets                  │
  │    (Intelligence Layer)          │
  │                                  │
  │  Classifies intent, decomposes   │
  │  into steps, orchestrates        │
  │  specialist skills, tracks       │
  │  progress, handles failures      │
  └──┬──────┬──────┬──────┬────┬────┘
     │      │      │      │    │
     ▼      ▼      ▼      ▼    ▼
  /archi  /ship  /insp  /tro  /craft
  tect          ect    uble   -module
     │      │      │    shoot    │
     └──────┴──────┴──────┴─────┘
                    │
                    ▼
            /platform-ops
          (Raptor CLI executor)
                    │
                    ▼
            /log-analyzer
          (Deployment log parser)
```

## Skills

### User-Facing Skills

| Skill | Description |
|-------|-------------|
| `/facets` | **Entry point.** Describe anything in plain English — it plans, delegates, and delivers |
| `/architect` | Design and build infrastructure from natural language descriptions |
| `/ship` | Deploy changes safely with risk assessment and environment gates |
| `/inspect` | Visualize infrastructure state with ASCII diagrams and health status |
| `/troubleshoot` | Diagnose failures from symptoms — forms hypotheses, gathers evidence, prescribes fixes |
| `/craft-module` | Create reusable Terraform/Facets modules from requirements |

### Internal Skills (auto-delegated, never invoked directly)

| Skill | Description |
|-------|-------------|
| `/platform-ops` | Translates intent into Raptor CLI commands |
| `/log-analyzer` | Parses deployment logs for root cause analysis |

## Usage Examples

### Design Infrastructure

```
/facets I need a 3-tier web app with a React frontend, Node.js API, and PostgreSQL database
```

### Deploy Changes

```
/facets deploy my changes to staging
```

### Inspect State

```
/facets what's running in production?
```

### Troubleshoot Failures

```
/facets the latest deploy failed, what happened?
```

### Build a Module

```
/facets I need a custom Redis cache component with HA support
```

### Use Individual Skills

```
/architect add a message queue between my API and worker service
/ship deploy to production
/inspect compare staging and production
/troubleshoot the database is slow
/craft-module build a Terraform module for S3 with versioning and lifecycle rules
```

## Architecture

```
  USER (plain English)
   │
   ├── /facets ─────────────────── orchestrates everything
   │    │
   │    ├── /architect ──────────── design + build infrastructure
   │    │    └── /platform-ops ──── raptor CLI execution (fork)
   │    │
   │    ├── /ship ───────────────── safe deployments with risk gates
   │    │    ├── /platform-ops ──── raptor CLI execution (fork)
   │    │    └── /troubleshoot ──── failure diagnosis (if deploy fails)
   │    │
   │    ├── /inspect ────────────── state visualization + health
   │    │    └── /platform-ops ──── raptor CLI execution (fork)
   │    │
   │    ├── /troubleshoot ───────── diagnosis + remediation
   │    │    ├── /platform-ops ──── raptor CLI execution (fork)
   │    │    ├── /log-analyzer ──── log parsing (fork)
   │    │    └── /ship ──────────── deploy fixes
   │    │
   │    └── /craft-module ───────── module engineering
   │         └── /platform-ops ──── raptor CLI execution (fork)
   │
   ├── /architect ───────────────── direct design (standalone)
   ├── /ship ────────────────────── direct deploy (standalone)
   ├── /inspect ─────────────────── direct inspect (standalone)
   ├── /troubleshoot ────────────── direct diagnose (standalone)
   └── /craft-module ────────────── direct build (standalone)
```

## v1 vs v2

| | **v1** (`facets-plugin`) | **v2** (`facets-plugin-v2`) |
|---|---|---|
| **Approach** | CLI-oriented — you know the commands | Natural language — just describe what you want |
| **Entry point** | Individual skills (`/blueprint`, `/raptor`) | Single entry point (`/facets`) that orchestrates |
| **Audience** | Platform engineers familiar with Raptor CLI | Anyone — no CLI knowledge needed |
| **Output style** | Structured CLI results | ASCII diagrams + plain English narratives |
| **Error handling** | Manual — you debug the CLI output | Automatic — hypotheses, evidence, root cause chains |
| **Deployment** | Direct CLI commands | Risk-assessed with environment gates |

Both plugins can be installed side-by-side. Use v1 when you want direct CLI control, v2 when you want to speak plain English.

## License

MIT
