# Facets Cloud — Claude Code Plugin

Claude Code skills for the [Facets Cloud](https://facets.cloud) platform. Manage blueprints, develop IaC modules, debug releases, and execute Raptor CLI operations — all from Claude Code.

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- [Raptor CLI](https://github.com/Facets-cloud/raptor-releases) installed and authenticated
- Terraform >= 1.5.0 (for module development)

### Install Raptor CLI

```bash
# macOS (Apple Silicon)
curl -L -o /usr/local/bin/raptor \
  https://github.com/Facets-cloud/raptor-releases/releases/latest/download/raptor-darwin-arm64
chmod +x /usr/local/bin/raptor

# macOS (Intel)
curl -L -o /usr/local/bin/raptor \
  https://github.com/Facets-cloud/raptor-releases/releases/latest/download/raptor-darwin-amd64
chmod +x /usr/local/bin/raptor

# Linux
curl -L -o /usr/local/bin/raptor \
  https://github.com/Facets-cloud/raptor-releases/releases/latest/download/raptor-linux-amd64
chmod +x /usr/local/bin/raptor

# Authenticate
raptor login
raptor auth whoami
```

## Installation

```bash
/install github:Facets-cloud/claude-plugin
```

## Skills

| Skill | Type | Description |
|-------|------|-------------|
| `/blueprint` | Workflow | Design and manage Facets infrastructure blueprints |
| `/module-design` | Guide | Bundle vs separate module decision framework |
| `/module-development` | Workflow | Create Facets IaC + standard Terraform modules |
| `/release-debug` | Workflow | Diagnose deployment and release failures |
| `/raptor` | Subagent | Execute Raptor CLI commands (forked) |
| `/analyze-logs` | Subagent | Analyze deployment logs for errors (forked) |

### `/blueprint` — Blueprint Design & Management

Design and manage Facets infrastructure blueprints. Covers projects, resources, environments, overrides, releases, variables, and architecture patterns. Delegates raptor commands to `/raptor`.

```
/blueprint list all resources in project my-stack
/blueprint create a release for project my-stack environment prod
```

### `/module-design` — Module Design Decision Guide

Pure decision framework (no tools) for determining whether to bundle or separate infrastructure into Facets modules. Includes decision trees, relationship types, and real-world examples.

```
/module-design should I bundle subnets into my VPC module or separate them?
```

### `/module-development` — Module Development

Create Facets IaC modules (facets.yaml + Terraform) or standard Terraform modules following best practices. Full lifecycle: design, implement, validate, upload, publish.

```
/module-development create a postgres module for AWS RDS
/module-development create a standard terraform module for S3 bucket
```

### `/release-debug` — Release Debugger

Diagnose deployment failures. Delegates to `/raptor` for fetching logs and configs, and `/analyze-logs` for structured error analysis.

```
/release-debug the latest release failed in project my-stack environment staging
```

### `/raptor` — Raptor Operations (Subagent)

Isolated executor for Raptor CLI commands. Runs in a forked context — other skills delegate raptor work here. Complete command reference for GET, SET, APPLY, DELETE, CREATE, LOGS, and AUTH.

```
/raptor get schema for service/k8s/0.2
/raptor list projects
/raptor create release for project my-stack environment dev
```

### `/analyze-logs` — Log Analyzer (Subagent)

Isolated log analysis agent. Parses Terraform, Kubernetes, cloud provider, and CI/CD logs. Classifies errors, traces root cause chains, returns structured diagnoses.

```
/analyze-logs /tmp/deployment_logs.txt
```

## Architecture

```
  USER
   |
   +-- /blueprint ----------+--- /raptor (fork) --- raptor CLI
   |                        |
   +-- /module-development -+--- /raptor (fork) --- raptor CLI
   |                        |
   +-- /release-debug ------+--- /raptor (fork) --- raptor CLI
   |                        |
   |                        +--- /analyze-logs (fork) --- Read+Grep
   |
   +-- /module-design  (standalone, no tools)
   |
   +-- /raptor         (standalone subagent, Bash)
   |
   +-- /analyze-logs   (standalone subagent, Read+Grep)
```

## License

MIT
