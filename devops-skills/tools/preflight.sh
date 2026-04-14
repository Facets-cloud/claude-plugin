#!/usr/bin/env bash
# preflight.sh — Check tools + credentials for a devops skill
#
# Usage: tools/preflight.sh <skill-name>
# Output: JSON with check results and install guidance
#
# Example:
#   tools/preflight.sh k8s-debug
#   tools/preflight.sh tf-review
#   tools/preflight.sh all          # Check everything

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Check Functions ───────────────────────────────────────────────

check_cli() {
  local name="$1"
  local version_cmd="${2:-$name --version}"
  local install_cmd="$3"

  if command -v "$name" &>/dev/null; then
    local version
    version=$(eval "$version_cmd" 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+[.0-9]*' | head -1 || echo "unknown")
    echo "{\"name\":\"$name\",\"type\":\"cli\",\"status\":\"ok\",\"version\":\"$version\"}"
  else
    echo "{\"name\":\"$name\",\"type\":\"cli\",\"status\":\"missing\",\"fix\":\"$install_cmd\"}"
  fi
}

check_env() {
  local name="$1"
  local fix="$2"

  if [ -n "${!name:-}" ]; then
    echo "{\"name\":\"$name\",\"type\":\"cred\",\"status\":\"ok\",\"value\":\"***set***\"}"
  else
    echo "{\"name\":\"$name\",\"type\":\"cred\",\"status\":\"missing\",\"fix\":\"$fix\"}"
  fi
}

check_file() {
  local name="$1"
  local path="$2"
  local fix="$3"

  if [ -f "$path" ]; then
    echo "{\"name\":\"$name\",\"type\":\"file\",\"status\":\"ok\",\"path\":\"$path\"}"
  else
    echo "{\"name\":\"$name\",\"type\":\"file\",\"status\":\"missing\",\"fix\":\"$fix\"}"
  fi
}

check_connection() {
  local name="$1"
  local test_cmd="$2"
  local fix="$3"

  if eval "$test_cmd" &>/dev/null 2>&1; then
    echo "{\"name\":\"$name\",\"type\":\"conn\",\"status\":\"ok\"}"
  else
    echo "{\"name\":\"$name\",\"type\":\"conn\",\"status\":\"missing\",\"fix\":\"$fix\"}"
  fi
}

# ─── Skill Checks ─────────────────────────────────────────────────

checks_k8s_debug() {
  check_cli "kubectl" "kubectl version --client --short 2>/dev/null || kubectl version --client" "${SCRIPT_DIR}/installers/kubectl.sh"
  check_cli "jq" "jq --version" "brew install jq"
  check_file "kubeconfig" "${KUBECONFIG:-$HOME/.kube/config}" "export KUBECONFIG=~/.kube/config  # or: aws eks update-kubeconfig --name <cluster>"
  check_connection "cluster" "kubectl cluster-info" "Check KUBECONFIG and cluster connectivity"
}

checks_tf_review() {
  if command -v terraform &>/dev/null; then
    check_cli "terraform" "terraform version" "${SCRIPT_DIR}/installers/terraform.sh"
  elif command -v tofu &>/dev/null; then
    check_cli "tofu" "tofu version" "${SCRIPT_DIR}/installers/terraform.sh"
  else
    echo "{\"name\":\"terraform/tofu\",\"type\":\"cli\",\"status\":\"missing\",\"fix\":\"${SCRIPT_DIR}/installers/terraform.sh\"}"
  fi
  check_cli "jq" "jq --version" "brew install jq"
}

checks_cloud_cost() {
  check_cli "aws" "aws --version" "${SCRIPT_DIR}/installers/cloud-cli.sh"
  check_cli "gcloud" "gcloud version 2>/dev/null | head -1" "${SCRIPT_DIR}/installers/cloud-cli.sh"
  check_cli "jq" "jq --version" "brew install jq"
  check_connection "aws-auth" "aws sts get-caller-identity" "aws configure sso  # or export AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY"
}

checks_secrets_audit() {
  check_cli "gitleaks" "gitleaks version" "${SCRIPT_DIR}/installers/gitleaks.sh"
  check_cli "git" "git --version" "Install git from https://git-scm.com"
}

checks_docker_optimize() {
  check_cli "docker" "docker --version" "Install Docker Desktop: https://docs.docker.com/get-docker/"
  check_cli "trivy" "trivy --version" "${SCRIPT_DIR}/installers/docker-tools.sh"
  check_cli "dive" "dive --version 2>&1 | head -1" "${SCRIPT_DIR}/installers/docker-tools.sh"
}

checks_incident_rca() {
  checks_k8s_debug
  check_cli "aws" "aws --version" "${SCRIPT_DIR}/installers/cloud-cli.sh"
  check_cli "gcloud" "gcloud version 2>/dev/null | head -1" "${SCRIPT_DIR}/installers/cloud-cli.sh"
}

# ─── Main ──────────────────────────────────────────────────────────

skill="${1:-}"

if [ -z "$skill" ]; then
  echo "Usage: tools/preflight.sh <skill-name|all>"
  echo "Skills: k8s-debug, tf-review, cloud-cost, secrets-audit, docker-optimize, incident-rca"
  exit 1
fi

echo "{"
echo "  \"skill\": \"$skill\","

# Collect checks
checks=()
case "$skill" in
  k8s-debug)       mapfile -t checks < <(checks_k8s_debug) ;;
  tf-review)       mapfile -t checks < <(checks_tf_review) ;;
  cloud-cost)      mapfile -t checks < <(checks_cloud_cost) ;;
  secrets-audit)   mapfile -t checks < <(checks_secrets_audit) ;;
  docker-optimize) mapfile -t checks < <(checks_docker_optimize) ;;
  incident-rca)    mapfile -t checks < <(checks_incident_rca) ;;
  all)
    mapfile -t checks < <(
      checks_k8s_debug
      checks_tf_review
      checks_cloud_cost
      checks_secrets_audit
      checks_docker_optimize
    )
    ;;
  *) echo "  \"error\": \"Unknown skill: $skill\""; echo "}"; exit 1 ;;
esac

# Compute readiness
ready=true
install_cmds=()
for check in "${checks[@]}"; do
  if echo "$check" | grep -q '"status":"missing"'; then
    ready=false
    fix=$(echo "$check" | grep -oP '"fix":"[^"]*"' | sed 's/"fix":"//;s/"$//')
    [ -n "$fix" ] && install_cmds+=("$fix")
  fi
done

echo "  \"ready\": $ready,"
echo "  \"checks\": ["
for i in "${!checks[@]}"; do
  comma=","
  [ "$i" -eq $((${#checks[@]} - 1)) ] && comma=""
  echo "    ${checks[$i]}$comma"
done
echo "  ],"
echo "  \"install_commands\": ["
for i in "${!install_cmds[@]}"; do
  comma=","
  [ "$i" -eq $((${#install_cmds[@]} - 1)) ] && comma=""
  echo "    \"${install_cmds[$i]}\"$comma"
done
echo "  ]"
echo "}"
