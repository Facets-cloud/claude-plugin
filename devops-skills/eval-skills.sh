#!/bin/bash
# eval-skills.sh — LLM-judged evaluation of skill quality
# Uses local Claude Code to: (1) run each eval prompt, (2) judge assertions
#
# Usage:
#   ./eval-skills.sh                        # Eval all skills
#   ./eval-skills.sh k8s-debug              # Eval one skill
#   ./eval-skills.sh k8s-debug 3            # Eval one specific scenario
#   DRY_RUN=1 ./eval-skills.sh              # Just show what would run
#
# Requirements:
#   - claude CLI (Claude Code) on PATH
#   - python3 for JSON parsing
#   - jq (optional, falls back to python3)
#
# How it works:
#   1. For each eval scenario, sends the prompt to Claude Code with the skill loaded
#   2. Captures Claude's response (what the skill would produce)
#   3. Sends the response + assertions to a judge prompt
#   4. Judge scores each assertion as PASS/FAIL with reasoning
#   5. Reports per-eval and overall scores
#
# Environment:
#   CLAUDE_CMD    Override claude binary (default: claude)
#   MODEL         Override model (default: sonnet)
#   DRY_RUN       Set to 1 to print prompts without running
#   VERBOSE       Set to 1 for full response output
#   TIMEOUT       Seconds per eval (default: 120)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
NC='\033[0m'

CLAUDE_CMD="${CLAUDE_CMD:-claude}"
MODEL="${MODEL:-sonnet}"
DRY_RUN="${DRY_RUN:-0}"
VERBOSE="${VERBOSE:-0}"
TIMEOUT="${TIMEOUT:-180}"
SKILLS_DIR="skills"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_BASE="$SCRIPT_DIR/eval-results"

mkdir -p "$RESULTS_BASE"

# ─── Helpers ───────────────────────────────────────────────

json_get() {
    python3 -c "
import json, sys
data = json.load(open('$1'))
path = '$2'.split('.')
obj = data
for p in path:
    if p.isdigit():
        obj = obj[int(p)]
    else:
        obj = obj[p]
if isinstance(obj, list):
    print(json.dumps(obj))
else:
    print(obj)
" 2>/dev/null
}

json_array_len() {
    python3 -c "
import json
data = json.load(open('$1'))
path = '$2'.split('.')
obj = data
for p in path:
    if p.isdigit():
        obj = obj[int(p)]
    else:
        obj = obj[p]
print(len(obj))
" 2>/dev/null
}

run_claude() {
    local prompt_file="$1"
    local output_file="$2"

    if [[ "$DRY_RUN" == "1" ]]; then
        echo "[DRY RUN] Would send prompt ($(wc -c < "$prompt_file") chars)" > "$output_file"
        return 0
    fi

    if command -v gtimeout &>/dev/null; then
        TIMEOUT_CMD="gtimeout"
    elif command -v timeout &>/dev/null; then
        TIMEOUT_CMD="timeout"
    else
        TIMEOUT_CMD=""
    fi

    if [[ -n "$TIMEOUT_CMD" ]]; then
        $TIMEOUT_CMD "$TIMEOUT" $CLAUDE_CMD --print \
            --model "$MODEL" \
            --max-turns 3 \
            -p "$(cat "$prompt_file")" > "$output_file" 2>/dev/null || true
    else
        $CLAUDE_CMD --print \
            --model "$MODEL" \
            --max-turns 3 \
            -p "$(cat "$prompt_file")" > "$output_file" 2>/dev/null || true
    fi
}

# ─── Main ──────────────────────────────────────────────────

target_skill="${1:-}"
target_eval="${2:-}"

echo "DevOps Skills Evaluation"
echo "======================================================"
echo "Model: $MODEL | Timeout: ${TIMEOUT}s | Claude: $CLAUDE_CMD"
[[ "$DRY_RUN" == "1" ]] && echo -e "${YELLOW}DRY RUN — no LLM calls will be made${NC}"
echo ""

total_evals=0
total_passed=0
total_failed=0
skill_results=()

for skill_dir in "$SKILLS_DIR"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")

    # Filter to target skill if specified
    [[ -n "$target_skill" && "$skill_name" != "$target_skill" ]] && continue

    eval_file="$skill_dir/evals/evals.json"
    skill_file="$skill_dir/SKILL.md"

    if [[ ! -f "$eval_file" ]]; then
        echo -e "${DIM}SKIP $skill_name — no evals/evals.json${NC}"
        continue
    fi

    if [[ ! -f "$skill_file" ]]; then
        echo -e "${RED}SKIP $skill_name — no SKILL.md${NC}"
        continue
    fi

    skill_content=$(cat "$skill_file")
    eval_count=$(json_array_len "$eval_file" "evals")

    # Per-skill results directory
    RESULTS_DIR="$RESULTS_BASE/$skill_name"
    mkdir -p "$RESULTS_DIR"

    echo -e "${BLUE}Evaluating: $skill_name ($eval_count scenarios)${NC}"
    echo ""

    skill_passed=0
    skill_failed=0
    report_lines=()
    report_lines+=("# Eval Report: $skill_name")
    report_lines+=("")
    report_lines+=("- **Date:** $(date -u '+%Y-%m-%d %H:%M UTC')")
    report_lines+=("- **Model:** $MODEL")
    report_lines+=("- **Skill version:** $(grep '^version:' "$skill_file" | head -1 | sed 's/version: //' | tr -d '\"')")
    report_lines+=("")
    report_lines+=("| Eval | Scenario | Result | Assertions |")
    report_lines+=("| ---- | -------- | ------ | ---------- |")

    for ((i=0; i<eval_count; i++)); do
        eval_id=$(json_get "$eval_file" "evals.$i.id")
        eval_prompt=$(json_get "$eval_file" "evals.$i.prompt")

        # Filter to target eval if specified
        [[ -n "$target_eval" && "$eval_id" != "$target_eval" ]] && continue

        # Get assertions as JSON array
        assertions_json=$(json_get "$eval_file" "evals.$i.assertions")
        assertion_count=$(python3 -c "
import json, sys
data = json.load(open('$eval_file'))
print(len(data['evals'][$i]['assertions']))
" 2>/dev/null || echo 0)

        echo -e "  Eval #$eval_id: ${DIM}${eval_prompt:0:70}...${NC}"

        # ── Step 1: Run the skill prompt ──
        response_file="$RESULTS_DIR/${skill_name}_eval${eval_id}_response.txt"
        prompt_file="$RESULTS_DIR/${skill_name}_eval${eval_id}_prompt.txt"

        cat > "$prompt_file" << SKILLEOF
You are a DevOps assistant with the following skill loaded:

---SKILL START---
$skill_content
---SKILL END---

The user says:
$eval_prompt

Respond as the skill instructs. Since you cannot actually run kubectl commands, describe exactly what commands you WOULD run, what you would look for in the output, and what your diagnosis and fix would be. Show your reasoning.
SKILLEOF

        run_claude "$prompt_file" "$response_file"
        response=$(cat "$response_file")

        [[ "$VERBOSE" == "1" ]] && echo -e "    ${DIM}Response: ${#response} chars${NC}"

        # ── Step 2: Judge assertions ──
        judge_file="$RESULTS_DIR/${skill_name}_eval${eval_id}_judge.txt"
        judge_prompt_file="$RESULTS_DIR/${skill_name}_eval${eval_id}_judge_prompt.txt"

        cat > "$judge_prompt_file" << JUDGEEOF
You are an eval judge. Score whether a skill response meets each assertion.

RESPONSE TO EVALUATE:
$response

ASSERTIONS TO CHECK:
$assertions_json

For each assertion, output exactly one line in this format:
PASS|<assertion text>|<brief reason>
or
FAIL|<assertion text>|<brief reason>

Output ONLY the scored lines, nothing else. One line per assertion.
JUDGEEOF

        run_claude "$judge_prompt_file" "$judge_file"
        judge_output=$(cat "$judge_file")

        # ── Step 3: Parse results ──
        eval_passed=0
        eval_failed=0

        while IFS='|' read -r verdict assertion reason; do
            verdict=$(echo "$verdict" | tr -d '[:space:]')
            case "$verdict" in
                PASS)
                    ((eval_passed++))
                    [[ "$VERBOSE" == "1" ]] && echo -e "    ${GREEN}PASS${NC} $assertion"
                    ;;
                FAIL)
                    ((eval_failed++))
                    echo -e "    ${RED}FAIL${NC} $assertion"
                    [[ -n "${reason:-}" ]] && echo -e "         ${DIM}$reason${NC}"
                    ;;
            esac
        done <<< "$judge_output"

        # Handle case where judge didn't return expected format
        scored=$((eval_passed + eval_failed))
        if [[ $scored -eq 0 ]]; then
            echo -e "    ${YELLOW}WARN: Judge returned no parseable results${NC}"
            eval_failed=$assertion_count
        fi

        if [[ $eval_failed -eq 0 ]]; then
            echo -e "  ${GREEN}  #$eval_id: PASS ($eval_passed/$scored assertions)${NC}"
            ((skill_passed++))
            report_lines+=("| #$eval_id | ${eval_prompt:0:50}... | PASS | $eval_passed/$scored |")
        else
            echo -e "  ${RED}  #$eval_id: FAIL ($eval_passed/$scored passed, $eval_failed failed)${NC}"
            ((skill_failed++))
            report_lines+=("| #$eval_id | ${eval_prompt:0:50}... | FAIL | $eval_passed/$scored |")
        fi

        ((total_evals++))
        echo ""
    done

    # Skill summary
    if [[ $skill_failed -eq 0 ]]; then
        echo -e "${GREEN}  $skill_name: ALL PASSED ($skill_passed/$((skill_passed+skill_failed)))${NC}"
        ((total_passed += skill_passed))
        report_lines+=("" "**Result: ALL PASSED ($skill_passed/$((skill_passed+skill_failed)))**")
    else
        echo -e "${RED}  $skill_name: $skill_failed FAILED, $skill_passed passed${NC}"
        ((total_passed += skill_passed))
        ((total_failed += skill_failed))
        report_lines+=("" "**Result: $skill_failed FAILED, $skill_passed passed**")
    fi

    # Write markdown report only for full suite runs (no specific eval ID)
    if [[ -z "$target_eval" ]]; then
        report_file="$RESULTS_DIR/report.md"
        {
            for line in "${report_lines[@]}"; do
                echo "$line"
            done
        } > "$report_file"
        echo "  Report: $report_file"
    fi
    echo ""
done

# ── Final Summary ──

echo "======================================================"
echo "Summary:"
echo "  Total evals: $total_evals"
echo -e "  ${GREEN}Passed: $total_passed${NC}"
[[ $total_failed -gt 0 ]] && echo -e "  ${RED}Failed: $total_failed${NC}"

score=0
[[ $total_evals -gt 0 ]] && score=$(python3 -c "print(round($total_passed / ($total_passed + $total_failed) * 100, 1))" 2>/dev/null || echo "0")
echo "  Score: ${score}%"
echo ""
echo "Results saved to: $RESULTS_BASE/"

if [[ $total_failed -eq 0 ]]; then
    echo -e "${GREEN}All evals passed.${NC}"
    exit 0
else
    echo -e "${RED}$total_failed eval(s) failed.${NC}"
    exit 1
fi
