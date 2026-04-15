# DevOps Skills for Claude Code

AI-powered DevOps skills — Kubernetes debugging, Terraform review, cloud cost analysis, secrets auditing, Docker optimization, and incident RCA.

## Install

### Claude Code Plugin (recommended)

```bash
# Add marketplace (one-time)
/plugin marketplace add Facets-cloud/claude-plugin

# Install
/plugin install devops-skills
```

### Manual

```bash
git clone https://github.com/Facets-cloud/claude-plugin.git ~/.devops-skills
ln -sf ~/.devops-skills/devops-skills/skills/* ~/.claude/skills/
```

### Update

```bash
# Plugin: auto-updates on restart
# Manual:
cd ~/.devops-skills && git pull
```

## Skills

| Skill | What It Does |
|-------|-------------|
| **k8s-debug** | Debug pods — CrashLoopBackOff, OOMKilled, ImagePull, Pending, stuck Terminating. Expert pattern matching, hypothesis-driven diagnosis, devil's advocate for ambiguous cases. |

*Planned: tf-review, cloud-cost, secrets-audit, docker-optimize, incident-rca (see [DESIGN.md](devops-skills/DESIGN.md))*

## How It Works

Skills teach Claude Code expert judgment — not kubectl commands it already knows.

```
You say: "my pod keeps crashing"
         │
         ▼
Skill loaded → agent gathers evidence → forms hypotheses → diagnoses root cause
         │
         ▼
RCA validated by tools/clis/validate-rca.js (deterministic field check)
         │
         ▼
Presents: causal chain diagram, confidence level, specific fix
```

## Evals

```bash
cd devops-skills

# Structural validation (no LLM)
./validate-skills.sh

# LLM-judged evals (uses local claude CLI)
./eval-skills.sh k8s-debug
```

## Customize

Edit `devops-skills/context/infra-context.md` with your org defaults (cloud provider, K8s version, naming conventions).

## License

MIT
