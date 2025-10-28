#!/bin/bash

# Facets Plugin Prerequisites Verification Script
# Checks if all required tools and authentication are properly set up

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
TOTAL_CHECKS=0

# Helper functions
print_header() {
    echo ""
    echo "=========================================="
    echo "  Facets Plugin Prerequisites Check"
    echo "=========================================="
    echo ""
}

print_check() {
    local status=$1
    local message=$2
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    if [ "$status" = "pass" ]; then
        echo -e "${GREEN}✓${NC} $message"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
    elif [ "$status" = "fail" ]; then
        echo -e "${RED}✗${NC} $message"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
    elif [ "$status" = "warn" ]; then
        echo -e "${YELLOW}⚠${NC} $message"
    else
        echo -e "  $message"
    fi
}

print_fix() {
    echo -e "  ${YELLOW}→${NC} Fix: $1"
}

print_summary() {
    echo ""
    echo "=========================================="
    echo "  Summary"
    echo "=========================================="
    echo -e "${GREEN}Passed:${NC} $CHECKS_PASSED / $TOTAL_CHECKS"
    echo -e "${RED}Failed:${NC} $CHECKS_FAILED / $TOTAL_CHECKS"
    echo ""

    if [ $CHECKS_FAILED -eq 0 ]; then
        echo -e "${GREEN}${BOLD}✓ All prerequisites met!${NC}"
        echo "You're ready to use the Facets plugin."
        return 0
    else
        echo -e "${RED}${BOLD}✗ Some prerequisites are missing.${NC}"
        echo "Please address the issues above before using the plugin."
        return 1
    fi
}

# Start verification
print_header

# Check 1: Raptor CLI installed
echo "${BOLD}Checking Raptor CLI...${NC}"
if command -v raptor &> /dev/null; then
    RAPTOR_PATH=$(which raptor)
    print_check "pass" "Raptor CLI is installed at: $RAPTOR_PATH"
else
    print_check "fail" "Raptor CLI is not installed"
    print_fix "Install from: https://github.com/Facets-cloud/raptor-releases"
    print_fix "macOS (Intel): curl -L -o raptor https://github.com/Facets-cloud/raptor-releases/releases/latest/download/raptor-darwin-amd64"
    print_fix "macOS (Apple Silicon): curl -L -o raptor https://github.com/Facets-cloud/raptor-releases/releases/latest/download/raptor-darwin-arm64"
    print_fix "Linux (amd64): curl -L -o raptor https://github.com/Facets-cloud/raptor-releases/releases/latest/download/raptor-linux-amd64"
    print_fix "Then: chmod +x raptor && sudo mv raptor /usr/local/bin/"
fi

# Check 2: Raptor version
if command -v raptor &> /dev/null; then
    RAPTOR_VERSION=$(raptor --version 2>&1 || echo "unknown")
    if [ "$RAPTOR_VERSION" != "unknown" ]; then
        print_check "pass" "Raptor version: $RAPTOR_VERSION"
    else
        print_check "warn" "Could not determine Raptor version"
    fi
fi

# Check 3: Raptor authentication
echo ""
echo "${BOLD}Checking Raptor Authentication...${NC}"
if command -v raptor &> /dev/null; then
    if RAPTOR_USER=$(raptor auth whoami 2>&1); then
        print_check "pass" "Authenticated as: $RAPTOR_USER"
    else
        print_check "fail" "Not authenticated with Raptor"
        print_fix "Run: raptor login"
        print_fix "Follow the prompts to authenticate with your Facets Control Plane"
    fi
else
    print_check "fail" "Cannot check authentication - raptor not installed"
fi

# Check 4: Facets credentials file
if [ -f ~/.facets/credentials ]; then
    print_check "pass" "Facets credentials file exists at ~/.facets/credentials"
else
    print_check "warn" "Facets credentials file not found at ~/.facets/credentials"
    print_fix "This will be created after running: raptor login"
fi

# Check 5: Can access projects
echo ""
echo "${BOLD}Checking Raptor Access...${NC}"
if command -v raptor &> /dev/null; then
    if raptor auth whoami &> /dev/null; then
        if PROJECTS=$(raptor get projects 2>&1); then
            PROJECT_COUNT=$(echo "$PROJECTS" | grep -c "^" || echo "0")
            if [ "$PROJECT_COUNT" -gt 0 ]; then
                print_check "pass" "Can access Facets projects ($PROJECT_COUNT found)"
            else
                print_check "warn" "Authenticated but no projects accessible"
                print_fix "Contact your Facets administrator to grant project access"
            fi
        else
            print_check "fail" "Cannot access Facets projects"
            print_fix "Verify your authentication: raptor auth whoami"
            print_fix "Check network connectivity to Facets Control Plane"
        fi
    else
        print_check "fail" "Cannot check project access - not authenticated"
    fi
else
    print_check "fail" "Cannot check project access - raptor not installed"
fi

# Check 6: uvx (for Module Development MCP)
echo ""
echo "${BOLD}Checking MCP Server Prerequisites...${NC}"
if command -v uvx &> /dev/null; then
    UVX_PATH=$(which uvx)
    print_check "pass" "uvx is installed at: $UVX_PATH"
else
    print_check "fail" "uvx is not installed (required for Module Development MCP)"
    print_fix "Install uv: curl -LsSf https://astral.sh/uv/install.sh | sh"
    print_fix "Then restart your shell"
fi

# Check 7: uv (parent of uvx)
if command -v uv &> /dev/null; then
    UV_VERSION=$(uv --version 2>&1 || echo "unknown")
    print_check "pass" "uv is installed: $UV_VERSION"
else
    print_check "warn" "uv is not installed (uvx needs this)"
    print_fix "Install uv: curl -LsSf https://astral.sh/uv/install.sh | sh"
fi

# Check 8: kubectl (optional - for K8s debugging skill)
echo ""
echo "${BOLD}Checking Optional Tools...${NC}"
if command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>&1 | head -n1 || echo "unknown")
    print_check "pass" "kubectl is installed: $KUBECTL_VERSION"
    print_fix "Available for K8s debugging skill"
else
    print_check "warn" "kubectl is not installed (optional - needed for K8s debugging)"
    print_fix "The K8s operations skill requires kubectl"
    print_fix "Install: https://kubernetes.io/docs/tasks/tools/"
fi

# Check 9: Profile configuration
echo ""
echo "${BOLD}Checking Profile Configuration...${NC}"

# Check if .mcp.json exists in current directory
if [ -f ".mcp.json" ]; then
    # Extract FACETS_PROFILE value from .mcp.json
    if command -v grep &> /dev/null && command -v sed &> /dev/null; then
        MCP_PROFILE=$(grep -m1 "FACETS_PROFILE" .mcp.json | sed 's/.*: *"\(.*\)".*/\1/')
        if [ -n "$MCP_PROFILE" ]; then
            print_check "pass" "Plugin configured to use profile: $MCP_PROFILE"

            # Check if this profile exists in credentials
            if [ -f ~/.facets/credentials ]; then
                if grep -q "^\[$MCP_PROFILE\]" ~/.facets/credentials; then
                    print_check "pass" "Profile '$MCP_PROFILE' exists in ~/.facets/credentials"
                else
                    print_check "fail" "Profile '$MCP_PROFILE' NOT found in ~/.facets/credentials"
                    print_fix "Option 1: Run: raptor login --profile $MCP_PROFILE"
                    print_fix "Option 2: Edit .mcp.json to use an existing profile name"
                fi
            fi
        else
            print_check "warn" "Could not detect FACETS_PROFILE in .mcp.json"
        fi
    fi
else
    print_check "warn" ".mcp.json not found in current directory"
    print_fix "Run this script from the plugin directory: marketplace/facets-plugin/"
fi

# Check 10: Shell PATH
echo ""
echo "${BOLD}Checking Shell Configuration...${NC}"
if echo "$PATH" | grep -q "/usr/local/bin"; then
    print_check "pass" "/usr/local/bin is in PATH"
else
    print_check "warn" "/usr/local/bin is not in PATH"
    print_fix "Add to PATH: export PATH=\"/usr/local/bin:\$PATH\""
    print_fix "Add to shell config (~/.bashrc, ~/.zshrc): echo 'export PATH=\"/usr/local/bin:\$PATH\"' >> ~/.zshrc"
fi

# Print summary and exit
echo ""
print_summary
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "Next steps:"
    echo "  1. Install the plugin: /plugin install facets-plugin"
    echo "  2. Start using Facets skills and agents in Claude Code"
    echo ""
    echo "Available skills:"
    echo "  • Infrastructure Resource Management"
    echo "  • Configuration Management"
    echo "  • Kubernetes Operations and Debugging"
    echo "  • Terraform Module Development for Facets"
    echo ""
    echo "Available agents (8 total):"
    echo "  Universal Context (Haiku):"
    echo "    • raptor-context-provider (project/environment discovery)"
    echo "    • raptor-command-finder (command discovery)"
    echo "  Infrastructure Management (Haiku):"
    echo "    • schema-inspector (schema documentation)"
    echo "    • resource-schema-interpreter (configuration guidance)"
    echo "  Module Development (Sonnet):"
    echo "    • module-explorer (module pattern analysis)"
    echo "    • dependency-resolver (dependency analysis)"
    echo "    • module-validator (validation and conventions)"
fi

exit $EXIT_CODE
