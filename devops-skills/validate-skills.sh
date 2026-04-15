#!/bin/bash
# validate-skills.sh — Structural validation of skill files
# No LLM required — pure bash checks against the agent skills spec
#
# Usage: ./validate-skills.sh [skills_dir]

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SKILLS_DIR="${1:-skills}"
ISSUES=0
WARNINGS=0
PASSED=0

echo "Auditing skills against Agent Skills Specification"
echo "======================================================"
echo ""

for skill_dir in "$SKILLS_DIR"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    skill_file="$skill_dir/SKILL.md"
    skill_errors=()
    skill_warnings=()

    # Check SKILL.md exists
    if [[ ! -f "$skill_file" ]]; then
        echo -e "${RED}FAIL $skill_name${NC}"
        echo "   Missing SKILL.md"
        ((ISSUES++))
        continue
    fi

    # Extract frontmatter
    frontmatter=$(sed -n '/^---$/,/^---$/p' "$skill_file" | sed '1d;$d')

    if [[ -z "$frontmatter" ]]; then
        echo -e "${RED}FAIL $skill_name${NC}"
        echo "   Missing YAML frontmatter (---)"
        ((ISSUES++))
        continue
    fi

    # Title validation
    title=$(echo "$frontmatter" | grep "^title:" | sed 's/^title: //' | tr -d '"')
    if [[ -z "$title" ]]; then
        skill_errors+=("Missing 'title' field in frontmatter")
    fi

    # Description validation
    description=$(echo "$frontmatter" | grep "^description:" | head -1 | sed 's/^description: //' | tr -d '"')
    if [[ -z "$description" ]]; then
        skill_errors+=("Missing 'description' field in frontmatter")
    else
        desc_len=${#description}
        if [[ $desc_len -gt 1024 ]]; then
            skill_errors+=("Description too long: $desc_len chars (max 1024)")
        fi
    fi

    # Triggers validation
    triggers=$(echo "$frontmatter" | grep "^triggers:" | head -1)
    if [[ -z "$triggers" ]]; then
        skill_warnings+=("Missing 'triggers' field — skill may not auto-activate")
    fi

    # Version validation
    version=$(echo "$frontmatter" | grep "^version:" | head -1)
    if [[ -z "$version" ]]; then
        skill_warnings+=("Missing 'version' field")
    fi

    # Line count check
    line_count=$(wc -l < "$skill_file" | tr -d ' ')
    if [[ $line_count -gt 500 ]]; then
        skill_warnings+=("SKILL.md is $line_count lines (recommended <500, move details to references/)")
    fi

    # Evals check
    if [[ ! -f "$skill_dir/evals/evals.json" ]]; then
        skill_warnings+=("No evals found — add evals/evals.json for quality validation")
    else
        # Validate evals.json is valid JSON
        if ! python3 -m json.tool "$skill_dir/evals/evals.json" >/dev/null 2>&1; then
            skill_errors+=("evals/evals.json is not valid JSON")
        else
            eval_count=$(python3 -c "import json; d=json.load(open('$skill_dir/evals/evals.json')); print(len(d.get('evals',[])))" 2>/dev/null || echo 0)
            if [[ "$eval_count" -lt 3 ]]; then
                skill_warnings+=("Only $eval_count evals — recommend at least 6 for coverage")
            fi
        fi
    fi

    # Report
    if [[ ${#skill_errors[@]} -gt 0 ]]; then
        echo -e "${RED}FAIL $skill_name${NC}"
        for error in "${skill_errors[@]}"; do
            echo -e "   ${RED}Error:${NC} $error"
        done
        for warning in "${skill_warnings[@]}"; do
            echo -e "   ${YELLOW}Warn:${NC} $warning"
        done
        ((ISSUES++))
    elif [[ ${#skill_warnings[@]} -gt 0 ]]; then
        echo -e "${YELLOW}WARN $skill_name${NC}"
        for warning in "${skill_warnings[@]}"; do
            echo -e "   ${YELLOW}Warn:${NC} $warning"
        done
        ((WARNINGS++))
    else
        echo -e "${GREEN}PASS $skill_name${NC}"
        ((PASSED++))
    fi
done

echo ""
echo "======================================================"
echo "Summary:"
echo -e "  ${GREEN}Passed: $PASSED${NC}"
[[ $WARNINGS -gt 0 ]] && echo -e "  ${YELLOW}Warnings: $WARNINGS${NC}"
[[ $ISSUES -gt 0 ]] && echo -e "  ${RED}Failed: $ISSUES${NC}"
echo ""

if [[ $ISSUES -eq 0 ]]; then
    echo -e "${GREEN}All skills valid.${NC}"
    exit 0
else
    echo -e "${RED}$ISSUES skill(s) have errors.${NC}"
    exit 1
fi
