# DevOps Skills — Design Document

A Claude Code plugin providing 6 DevOps skills backed by CLI tools with credential
preflight checks. Inspired by [marketingskills](https://github.com/coreyhaines31/marketingskills).

## Architecture

```
User invokes skill (e.g. /k8s-debug)
       │
       ▼
SKILL.md loaded → agent follows workflow
       │
       ▼
PREFLIGHT CHECK (tools/preflight.sh <skill>)
  ┌──────────────────────────────────────────┐
  │ 1. CLI installed?      ✓ ok / ✗ install  │
  │ 2. Credentials set?    ✓ ok / ✗ guide    │
  │ 3. Connectivity?       ✓ ok / ✗ fix      │
  └──────────────────────────────────────────┘
       │ all green
       ▼
RUN WORKFLOW using tools/clis/<tool>.js
       │
       ▼
JSON output → agent interprets → next step
```

## Directory Structure

```
devops-skills/
├── .claude-plugin/
│   └── plugin.json              # Plugin metadata for Claude Code marketplace
│
├── skills/                      # One dir per skill, each with SKILL.md
│   ├── k8s-debug/SKILL.md      # Kubernetes pod/service debugging
│   ├── tf-review/SKILL.md      # Terraform plan safety review
│   ├── cloud-cost/SKILL.md     # Cloud spend analysis & waste detection
│   ├── secrets-audit/SKILL.md  # Repo secret scanning & remediation
│   ├── docker-optimize/SKILL.md# Dockerfile optimization & CVE scanning
│   └── incident-rca/SKILL.md   # Production incident root cause analysis
│
├── tools/
│   ├── REGISTRY.md              # Master map: skill → tools → creds needed
│   ├── preflight.sh             # Check deps + creds, output JSON status
│   │
│   ├── clis/                    # Zero-dep wrappers → JSON stdout
│   │   ├── k8s.js               # kubectl wrapper (pods, deployments, logs, events)
│   │   ├── tf.js                # terraform plan parser (classify changes, flag danger)
│   │   ├── cloud-cost.js        # AWS CE / GCP billing query → structured cost data
│   │   ├── secret-scan.js       # gitleaks/trufflehog wrapper → findings JSON
│   │   ├── docker-analyze.js    # trivy + dive wrapper → CVEs + layer analysis
│   │   └── timeline.js          # Correlate K8s events + cloud events for RCA
│   │
│   └── installers/              # One-liner install scripts per dependency
│       ├── kubectl.sh
│       ├── terraform.sh
│       ├── cloud-cli.sh         # aws cli + gcloud
│       ├── gitleaks.sh
│       ├── docker-tools.sh      # trivy + dive
│       └── install-all.sh
│
├── context/
│   └── infra-context.md         # Foundation: org defaults, cloud, naming conventions
│
├── DESIGN.md                    # This file
└── README.md                    # User-facing install & usage guide
```

## Skills Spec

### 1. k8s-debug

| Field | Value |
|-------|-------|
| **Triggers** | pod crashing, OOMKilled, CrashLoopBackOff, ImagePullBackOff, pod pending, service unreachable, debug pod |
| **CLI tools** | kubectl |
| **Credentials** | KUBECONFIG or ~/.kube/config |
| **Preflight** | kubectl installed? → cluster reachable? → namespace accessible? |

**Workflow:**
1. **Identify** — list pods with non-Running status in target namespace
2. **Triage** — classify failure type:
   - CrashLoopBackOff → check logs (current + previous)
   - ImagePullBackOff → verify image name, registry auth, pull policy
   - Pending → check scheduling (cpu/memory, node affinity, taints)
   - OOMKilled → compare resource limits vs actual usage
   - Evicted → check node pressure conditions
3. **Diagnose** — parse logs for exceptions, events for warnings, describe for state
4. **Fix** — generate patch/manifest change for the root cause
5. **Verify** — rollout status, pod health check, endpoint validation

---

### 2. tf-review

| Field | Value |
|-------|-------|
| **Triggers** | review plan, terraform plan, is this safe, what will change, tf review |
| **CLI tools** | terraform or tofu |
| **Credentials** | Cloud provider creds (for plan generation) |
| **Preflight** | terraform/tofu installed? → providers initialized? |

**Workflow:**
1. **Capture** — `terraform plan -out=tfplan` then parse JSON output
2. **Classify** — group resource_changes by action: create (low), update (medium), replace (HIGH), delete (HIGH)
3. **Flag dangers** — delete on databases/storage/IAM, replace on stateful resources, security group 0.0.0.0/0, IAM Action:"*", removing prevent_destroy
4. **Blast radius** — count affected resources by type, check cross-environment impact
5. **Recommend** — SAFE / CAUTION / DANGER verdict with specific resource callouts

---

### 3. cloud-cost

| Field | Value |
|-------|-------|
| **Triggers** | what's expensive, cloud cost, find waste, cost report, right-size, unused resources |
| **CLI tools** | aws cli and/or gcloud |
| **Credentials** | AWS_PROFILE or GOOGLE_PROJECT |
| **Preflight** | aws/gcloud installed? → authenticated? → billing access? |

**Workflow:**
1. **Spend overview** — last 30 days, grouped by service, daily trend
2. **Top spenders** — sort by cost, show month-over-month delta
3. **Waste detection** — unattached EBS/disks, idle LBs, unused EIPs, old snapshots (>90d), oversized instances (CPU <10%)
4. **Right-sizing** — CloudWatch/Monitoring CPU+memory 14-day avg, recommend downsize if p95 CPU <40%, recommend spot if stateless
5. **Report** — total spend, top 5 services, waste found, savings estimate, cleanup commands

---

### 4. secrets-audit

| Field | Value |
|-------|-------|
| **Triggers** | scan for secrets, leaked secrets, check .env, credential scan, security scan |
| **CLI tools** | gitleaks |
| **Credentials** | none (local scanning) |
| **Preflight** | gitleaks installed? → inside git repo? |

**Workflow:**
1. **Scan repo** — `gitleaks detect --source . --report-format json`
2. **Scan git history** — `gitleaks detect --log-opts="--all"` (catches removed secrets)
3. **Check common locations** — .env files not in .gitignore, hardcoded passwords in docker-compose/CI configs, terraform with inline creds
4. **Classify severity** — CRITICAL (AWS keys, private keys in history), HIGH (API keys in files), MEDIUM (.env not gitignored), LOW (test creds that look real)
5. **Remediate** — rotate credential, remove from history (BFG/filter-branch), add to .gitignore, move to secrets manager, generate .gitleaks.toml allowlist for false positives

---

### 5. docker-optimize

| Field | Value |
|-------|-------|
| **Triggers** | optimize Dockerfile, shrink image, image too big, CVE scan, docker best practices |
| **CLI tools** | docker, trivy, dive |
| **Credentials** | none (local analysis) |
| **Preflight** | docker installed? → trivy installed? → dive installed? |

**Workflow:**
1. **Analyze** — `docker images` for size, `dive` for layer breakdown and wasted space %
2. **Security scan** — `trivy image --format json` → group by CRITICAL/HIGH/MEDIUM/LOW with CVE IDs and fix versions
3. **Dockerfile review** — check anti-patterns: :latest tag, no layer cleanup, COPY . . before deps, running as root, no .dockerignore, secrets in build args
4. **Optimize** — multi-stage build, minimal base (distroless/alpine/slim), layer ordering, .dockerignore, pin versions
5. **Verify** — rebuild, compare old vs new size, re-scan CVE count, smoke test healthcheck

---

### 6. incident-rca

| Field | Value |
|-------|-------|
| **Triggers** | why did prod go down, root cause, RCA, postmortem, incident timeline |
| **CLI tools** | kubectl, aws/gcloud, jq |
| **Credentials** | KUBECONFIG + cloud creds |
| **Preflight** | combines k8s-debug + cloud-cost preflight checks |

**Workflow:**
1. **Establish timeline** — when started, detected, mitigated, resolved
2. **Gather evidence** — K8s events (sorted by time), pod logs around incident, cloud provider events (CloudTrail/Audit Logs), recent deployments (rollout history, git log), recent config changes (terraform state, helm history)
3. **Correlate** — map events to timeline, identify what changed before incident, classify: deployment-caused / infrastructure-caused / external-caused / capacity-caused
4. **5-Whys** — structured causal chain from symptom to root cause
5. **Output** — structured RCA: summary, timeline table, root cause, contributing factors, impact, remediation done, prevention action items

---

## Preflight System

Every skill runs `tools/preflight.sh <skill>` before starting.

**Output contract:**
```json
{
  "skill": "k8s-debug",
  "ready": false,
  "checks": [
    {"name": "kubectl", "type": "cli",  "status": "ok",     "version": "1.29.2"},
    {"name": "KUBECONFIG","type": "cred","status": "missing","fix": "export KUBECONFIG=~/.kube/config"}
  ],
  "install_commands": ["export KUBECONFIG=~/.kube/config"]
}
```

**Skill behavior:**
- If `ready: true` → proceed with workflow
- If `ready: false` → show user the missing items and fix commands, do NOT proceed until all checks pass

## CLI Tool Contract

All wrappers in `tools/clis/` follow:

- **Zero dependencies** — Node.js 18+ built-ins only (no npm install)
- **Input**: `<tool> <resource> <action> [--option value]`
- **Output**: JSON to stdout
- **Errors**: `{"error": "message"}` to stderr, exit code 1
- **Credentials**: env vars, fail fast with install guidance
- **Timeout**: 30s default

## Installer Contract

All scripts in `tools/installers/` follow:

- Detect OS (macOS/Linux) and arch (amd64/arm64)
- Prefer brew on macOS, apt/yum on Linux
- Verify installation after install
- Idempotent — safe to re-run

## Context System

`context/infra-context.md` is a foundation file loaded alongside any skill.
Users customize it with their org defaults:

```markdown
## Organization Defaults
- Cloud: AWS (us-east-1 primary)
- K8s: EKS 1.29
- IaC: Terraform with S3 backend
- Secrets: AWS Secrets Manager
- Monitoring: Datadog

## Naming Conventions
- Resources: {team}-{service}-{env}
- Namespaces: {team}-{env}
```

## Distribution

```bash
# Claude Code plugin install
/plugin install devops-skills

# Or git clone
git clone https://github.com/Facets-cloud/claude-plugin.git
# Skills are in devops-skills/
```
