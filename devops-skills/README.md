# DevOps Skills

AI-powered DevOps skills for Claude Code. Kubernetes debugging, Terraform review, cloud cost analysis, and more.

## Install

```bash
git clone https://github.com/Facets-cloud/claude-plugin.git ~/.devops-skills
ln -sf ~/.devops-skills/devops-skills/skills/* ~/.claude/skills/
```

That's it. Claude Code auto-discovers skills in `~/.claude/skills/`.

## Update

```bash
cd ~/.devops-skills && git pull
```

## Skills

| Skill | What It Does |
|-------|-------------|
| **k8s-debug** | Debug pods — CrashLoopBackOff, OOMKilled, ImagePull, Pending, stuck Terminating. Expert pattern matching, hypothesis-driven diagnosis, devil's advocate for ambiguous cases. |

*Planned: tf-review, cloud-cost, secrets-audit, docker-optimize, incident-rca (see DESIGN.md)*

## How It Works

Skills are markdown files that teach Claude Code expert judgment — not kubectl commands it already knows.

```
You say: "my pod keeps crashing"
         │
         ▼
Skill loaded: k8s-debug/SKILL.md
         │
         ▼
Agent: gathers evidence → forms hypotheses → diagnoses root cause
         │
         ▼
Deterministic RCA check: tools/clis/validate-rca.js
         │
         ▼
Presents: causal chain diagram, confidence level, specific fix
```

## Tools

| Tool | What It Does |
|------|-------------|
| `tools/clis/validate-rca.js` | Deterministic RCA field checker — ensures diagnosis has evidence, root cause, causal chain, confidence, and fix before presenting to user |
| `tools/preflight.sh` | Checks CLI tools and credentials before investigation |

## Evals

```bash
cd devops-skills

# Structural validation (no LLM)
./validate-skills.sh

# LLM-judged evals (uses local claude CLI)
./eval-skills.sh k8s-debug

# Single scenario
./eval-skills.sh k8s-debug 3
```

Reports saved to `eval-results/<skill>/report.md`.

## Customize

Edit `context/infra-context.md` with your org defaults (cloud provider, K8s version, naming conventions). This is loaded alongside every skill.

## License

MIT
