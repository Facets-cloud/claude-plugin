# DevOps Skills

DevOps skills for AI coding agents — Kubernetes debugging, Terraform plan review, cloud cost analysis, secrets auditing, Docker optimization, and incident root cause analysis.

Built for Claude Code, compatible with Cursor, Windsurf, Codex, and any agent that reads `.agents/skills/`.

## Skills

| Skill | What It Does | Triggers |
|-------|-------------|----------|
| **k8s-debug** | Debug crashing pods, scheduling failures, OOMKills, image pull errors | `pod crashing`, `CrashLoopBackOff`, `debug pod` |
| **tf-review** | Review terraform plans for safety — flag destructive ops, blast radius | `review plan`, `is this safe`, `tf review` |
| **cloud-cost** | Find cloud waste — idle resources, oversized instances, cost trends | `what's expensive`, `find waste`, `cloud cost` |
| **secrets-audit** | Scan repos for leaked secrets, check git history, remediation guidance | `scan for secrets`, `credential scan` |
| **docker-optimize** | Shrink images, fix Dockerfiles, scan CVEs, multi-stage builds | `optimize Dockerfile`, `shrink image`, `CVE scan` |
| **incident-rca** | Structured root cause analysis — timeline, 5-whys, evidence gathering | `why did prod go down`, `RCA`, `postmortem` |

## Installation

### CLI Install (Recommended)

```bash
npx skills add Facets-cloud/claude-plugin --path devops-skills
```

Install specific skills only:

```bash
npx skills add Facets-cloud/claude-plugin --path devops-skills --skill k8s-debug tf-review
```

List available skills:

```bash
npx skills add Facets-cloud/claude-plugin --path devops-skills --list
```

### Claude Code Plugin

```bash
/plugin marketplace add Facets-cloud/claude-plugin
/plugin install devops-skills
```

### Install Into a Directory

Clone directly into a project or shared location:

```bash
# Into a project
git clone https://github.com/Facets-cloud/claude-plugin.git /tmp/claude-plugin
cp -r /tmp/claude-plugin/devops-skills/skills/* .agents/skills/
cp -r /tmp/claude-plugin/devops-skills/tools ./tools/devops

# Into a shared location (available to all projects)
git clone https://github.com/Facets-cloud/claude-plugin.git ~/.devops-skills
ln -sf ~/.devops-skills/devops-skills/skills/* ~/.claude/skills/
```

### Git Submodule

Pin to your repo so the whole team gets the same skills:

```bash
git submodule add https://github.com/Facets-cloud/claude-plugin.git .agents/claude-plugin
# Skills auto-discovered from .agents/claude-plugin/devops-skills/skills/
```

### SkillKit (Multi-Agent)

```bash
npx skillkit install Facets-cloud/claude-plugin --path devops-skills
```

### Manual Clone

```bash
git clone https://github.com/Facets-cloud/claude-plugin.git
cp -r claude-plugin/devops-skills/skills/* .agents/skills/
cp -r claude-plugin/devops-skills/tools ./devops-tools
```

### Fork & Customize

Fork the repo, edit `context/infra-context.md` with your org defaults, then install from your fork:

```bash
npx skills add your-org/claude-plugin --path devops-skills
```

## Prerequisites

Skills check their own dependencies before running via `tools/preflight.sh`. If something is missing, you get install guidance — not a cryptic failure.

```bash
# Check what a skill needs
tools/preflight.sh k8s-debug

# Check everything
tools/preflight.sh all
```

### Tool Requirements

| Tool | Skills That Need It | Install |
|------|-------------------|---------|
| kubectl | k8s-debug, incident-rca | `brew install kubectl` or `tools/installers/kubectl.sh` |
| terraform / tofu | tf-review | `brew install terraform` or `tools/installers/terraform.sh` |
| aws cli | cloud-cost, incident-rca | `brew install awscli` or `tools/installers/cloud-cli.sh` |
| gcloud | cloud-cost, incident-rca | `tools/installers/cloud-cli.sh` |
| gitleaks | secrets-audit | `brew install gitleaks` or `tools/installers/gitleaks.sh` |
| docker | docker-optimize | [Docker Desktop](https://docs.docker.com/get-docker/) |
| trivy | docker-optimize | `brew install trivy` or `tools/installers/docker-tools.sh` |
| dive | docker-optimize | `brew install dive` or `tools/installers/docker-tools.sh` |
| jq | all skills | `brew install jq` |

### Credential Requirements

| Credential | Skills That Need It | Setup |
|------------|-------------------|-------|
| KUBECONFIG | k8s-debug, incident-rca | `export KUBECONFIG=~/.kube/config` |
| AWS auth | cloud-cost, tf-review, incident-rca | `aws configure sso` or export keys |
| GCP auth | cloud-cost, tf-review | `gcloud auth application-default login` |

See `tools/REGISTRY.md` for full credential setup guides.

## Customization

### Organization Context

Edit `context/infra-context.md` to set your org defaults. This file is loaded alongside every skill, giving the agent awareness of your specific environment:

```markdown
## Organization Defaults
- Cloud: AWS (us-east-1 primary, us-west-2 DR)
- K8s: EKS 1.29, Karpenter for scaling
- IaC: Terraform with S3 backend
- Secrets: AWS Secrets Manager
- Monitoring: Datadog
```

### Adding Skills

Each skill is a directory with a `SKILL.md`:

```
skills/
└── my-new-skill/
    └── SKILL.md     # Frontmatter (name, description, triggers) + workflow markdown
```

PRs welcome — see `DESIGN.md` for the skill spec format.

## Project Structure

```
devops-skills/
├── .claude-plugin/plugin.json     # Plugin metadata
├── skills/                        # Skill definitions (SKILL.md per skill)
├── tools/
│   ├── REGISTRY.md                # Tool → credential → install mapping
│   ├── preflight.sh               # Dependency checker (JSON output)
│   ├── clis/                      # Zero-dep CLI wrappers (JSON stdout)
│   └── installers/                # One-liner install scripts
├── context/infra-context.md       # Org defaults (customize this)
├── DESIGN.md                      # Full architecture & skill specs
└── README.md                      # This file
```

## License

MIT
