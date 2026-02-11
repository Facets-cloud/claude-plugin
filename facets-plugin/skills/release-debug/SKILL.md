---
name: release-debug
description: Diagnose deployment and release failures using Raptor CLI. Use when user mentions deployment failed, release error, release debugging, deployment logs, or terraform errors in releases.
allowed-tools: Bash, Read, Glob, Grep
---

# Release Debugger

Diagnose deployment failures and provide actionable solutions using Raptor CLI.

## Platform Context

- Developer self-service platform using JSON configuration validated against schemas
- Generates Terraform from validated configurations
- All changes go through managed releases (no direct infrastructure access)
- Use "trigger release" not "run terraform", "environment" not "cluster"

## Release Types

- **Full/Selective Release**: Available to regular users (with allow_destroy/refresh options)
- **Custom Release**: Operations team only (for Terraform commands)
- Selective releases are NOT `terraform -target` - Facets handles dependencies safely

## Available Raptor Commands

**Fetch logs:**
```bash
raptor logs release --project PROJECT --environment ENV RELEASE_ID
raptor logs release --project PROJECT --environment ENV -f RELEASE_ID    # Follow/stream
```

**Get releases:**
```bash
raptor get releases --project PROJECT --environment ENV -o json
```

**Inspect resource configuration:**
```bash
raptor get resources --project PROJECT TYPE/NAME -o json
raptor get resource-overrides --project PROJECT --environment ENV TYPE/NAME -o json
raptor get resource-status --project PROJECT --environment ENV TYPE/NAME
raptor get resource-outputs --project PROJECT --environment ENV TYPE/NAME -o json
```

**Validate against schema:**
```bash
raptor get resource-type-schema TYPE/FLAVOR/VERSION
raptor get resource-type-inputs TYPE/FLAVOR/VERSION
raptor get resource-type-outputs TYPE/FLAVOR/VERSION
```

**Check valid expressions:**
```bash
raptor get resource-output-expressions --project PROJECT
```

**Download module code (for debugging):**
```bash
raptor get iac-module TYPE/FLAVOR/VERSION
raptor get iac-module TYPE/FLAVOR/VERSION -o ./modules/
```

## Subagent Delegation

This skill delegates to two subagent skills:

- **`/raptor`** — For ALL raptor CLI operations (fetching logs, getting resources, schemas, modules). Invoke `/raptor <task>` to delegate raptor commands.
- **`/analyze-logs`** — For log analysis after fetching logs. Invoke `/analyze-logs <log file path>` to get structured error diagnosis.

## Investigation Workflow

### 1. Extract Error Evidence

Delegate to `/raptor` to fetch deployment logs:
```
/raptor fetch release logs for project PROJECT environment ENV release RELEASE_ID and save to /tmp/deployment_logs.txt
```

Then delegate to `/analyze-logs` for structured analysis:
```
/analyze-logs /tmp/deployment_logs.txt
```

The log analyzer returns: critical failure, error classification, root cause chain, and evidence.

### 2. Analyze Resource Configuration

Delegate to `/raptor` to retrieve configuration:
```
/raptor get resource config and overrides for TYPE/NAME in project PROJECT environment ENV
```

Check:
- What values were provided?
- Missing or incorrect fields?
- Configuration vs operational problem?

### 3. Validate Against Schema

Delegate to `/raptor` to get schema:
```
/raptor get resource-type-schema for TYPE/FLAVOR/VERSION
```

Confirm:
- Field exists in schema
- Data type matches
- Required fields present
- Never guess configuration options

### 4. Download Module Code (When Needed)

Delegate to `/raptor` for module download:
```
/raptor download iac-module TYPE/FLAVOR/VERSION to ./debug-modules/
```

Then analyze with file tools (read, grep, glob):
- Check outputs.tf for valid attribute references
- Examine main.tf for resource definitions
- Review variables.tf for expected input structure

### 5. Classify Root Cause

| Error Type | Solution | Example |
|------------|----------|---------|
| **Configuration error** | Schema-validated JSON changes | Wrong field type, missing required field |
| **Operational error** | Infrastructure actions | Timeout, resource unavailable |
| **State issue** | Release options or custom release | State lock, state drift |
| **Module bug** | Module fix via registry workflow | Bad attribute reference, missing resource |

## Common Patterns

**State locks:**
```
Error acquiring the state lock
```
-> Go to Releases -> ellipsis menu -> Unlock State (ONLY for this specific error)

**Helm conflicts:**
```
Error: cannot re-use a name that is still in use
```
-> Delete conflicting release or use `--with-refresh` option

**Attribute errors:**
```
has no attribute "X"
```
-> Download module, check outputs.tf for valid attributes

**Resource timeouts:**
-> Fix the underlying resource issue, not the Helm timeout config

**Expression errors:**
```
invalid reference: ${type.name.out.field}
```
-> Check valid expressions:
```bash
raptor get resource-output-expressions --project PROJECT
```

## Response Format

Structure your diagnosis clearly:

**Deployment Status:** [FAILED/SUCCEEDED/IN_PROGRESS]

**Issue Summary**
What failed and the specific error.

**Root Cause**
Whether this is configuration, operational, state, or module issue.

**Solution**
Actionable steps:
- **Configuration Changes**: Schema-validated JSON with navigation path
- **Infrastructure Actions**: Release options or operational commands
- **Module Fixes**: Changes needed via module registry workflow

Always provide evidence for conclusions. Be direct and actionable.

## Debugging Checklist

1. Get the release ID and fetch logs
2. Identify the failing resource(s)
3. Parse the error message type
4. Get current resource config + overrides
5. Validate against schema
6. Download module if attribute/code issue
7. Classify root cause
8. Provide evidence-based fix
