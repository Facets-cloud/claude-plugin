# CLAUDE.md — DevOps Skills Plugin

## Mandatory: Eval Before Commit

**Before committing ANY change to a skill file (`skills/*/SKILL.md`), you MUST run evals for that skill and confirm they pass.**

```bash
cd devops-skills

# 1. Structural validation (always)
./validate-skills.sh

# 2. LLM evals for the changed skill (always)
./eval-skills.sh <skill-name>

# Example: changed k8s-debug skill
./eval-skills.sh k8s-debug
```

**Rules:**
- If `validate-skills.sh` fails → fix structural issues before committing
- If any eval fails → investigate whether the skill change broke it or the eval needs updating
- If you update a skill AND its evals in the same commit, run evals to confirm they pass together
- Eval results are saved to `eval-results/` — commit the summary report alongside skill changes
- Do NOT skip evals with `--no-verify` or by committing without running them

**Exception:** Changes to non-skill files (README, DESIGN.md, tools/, installers/) do not require evals.

## Eval Results

- Raw results (prompts, responses, judge output): `eval-results/<skill>/` — gitignored
- Summary reports: `eval-results/<skill>/summary.json` — committed for audit trail
- Run `./eval-skills.sh <skill>` to generate both

## Project Structure

```
devops-skills/
├── skills/<name>/SKILL.md           # Skill definitions (intelligent, not prescriptive)
├── skills/<name>/evals/evals.json   # Eval scenarios + assertions per skill
├── tools/clis/                      # Zero-dep Node.js CLI tools
├── tools/installers/                # One-liner install scripts
├── tools/preflight.sh               # Dependency + credential checker
├── tools/REGISTRY.md                # Skill → tools → creds mapping
├── validate-skills.sh               # Structural validator (bash, no LLM)
├── eval-skills.sh                   # LLM-judged evals (uses claude CLI)
├── eval-results/                    # Eval outputs (raw gitignored, summaries committed)
├── context/infra-context.md         # Org defaults template
├── DESIGN.md                        # Full spec for all 6 planned skills
└── README.md                        # Install guide
```

## Skill Authoring Guidelines

- Skills teach expert judgment, not kubectl commands — the LLM already knows kubectl
- Keep under 500 lines (under 250 preferred)
- Include `evals/evals.json` with 6-12 scenarios covering:
  - Core functionality (happy path)
  - Expert judgment (non-obvious patterns)
  - Boundary rejection (out-of-scope requests)
  - Preflight failure handling
- Use `tools/clis/validate-rca.js` for deterministic RCA field checking
- Devil's advocate pattern for ambiguous diagnoses

## Tool Contract

All tools in `tools/clis/` are zero-dependency Node.js (Node 18+):
- Input: `<tool> <resource> <action> [--option value]`
- Output: JSON to stdout
- Errors: `{"error": "message"}` to stderr, exit code 1
