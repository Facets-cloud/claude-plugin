# Configuration Management

Intelligent management of project variables, secrets, and environment-specific overrides across the infrastructure lifecycle.

## Prerequisites

**Platform Knowledge:** Read [FACETS_DOMAIN.md](../../docs/FACETS_DOMAIN.md) for Facets platform fundamentals.

This skill assumes understanding of:
- Facets orchestration layer and terminology
- Configuration management concepts (variables, secrets, output expressions)
- Environment hierarchy and override patterns
- Proper reference syntax for dynamic values

## Domain

Configuration data management: variables, secrets, environment overrides, and dynamic value expressions. Handles configuration at project level and environment-specific customization.

## Capabilities

**Variable & Secret Management:**
- Create and manage project-level variables and secrets
- Set environment-specific values for variables
- Understand when to use variables vs secrets
- Guide proper secret handling

**Environment Overrides:**
- Configure environment-specific resource overrides
- Manage configuration drift across environments
- Progressive rollout patterns (dev → staging → prod)

**Dynamic References:**
- Guide usage of output expressions (${...})
- Validate reference syntax
- Troubleshoot missing or invalid references

## Available Agents

- **raptor-context-provider** - Establish project/environment context (Haiku)
- **dependency-resolver** - Validate output expressions and references (Sonnet)

## Intelligence Guidelines

**Security Awareness:**
Distinguish between regular variables (exposed) and secrets (encrypted). Guide users to use secrets for sensitive data (passwords, API keys, tokens).

**Environment Strategy:**
Understand environment promotion patterns. Help users configure appropriately per environment (loose in dev, tight in prod).

**Reference Intelligence:**
When users reference other resources or variables, validate syntax and existence. Suggest available outputs when needed.

**Minimal Defaults:**
Start with project-level defaults. Add environment overrides only when actually needed. Avoid premature optimization.

**Change Impact:**
When updating variables, understand which resources depend on them. Warn about deployment implications.

## Raptor Commands

**Variables:** `raptor get/create/set/delete variable NAME -p PROJECT [--secret] [-e ENV]`

**Overrides:** `raptor get/set resource-overrides -p PROJECT -e ENV RESOURCE_TYPE/NAME [-f overrides.json]`

**Outputs:** `raptor get resource-outputs/resource-output-expressions -p PROJECT [RESOURCE_TYPE/NAME]`

## Workflow Intelligence

**Variable Creation:**
1. Understand user's configuration need
2. Determine if secret or variable (ask if unclear)
3. Set appropriate value
4. Guide usage in resource configurations (${...} syntax)

**Environment-Specific Values:**
1. Understand which environments need different values
2. Set environment-specific overrides
3. Validate environment exists
4. Note that resources must be re-deployed for changes to take effect

**Override Management:**
1. Fetch current configuration
2. Understand desired environment-specific changes
3. Create minimal override (only changed fields)
4. Apply and validate

**Reference Troubleshooting:**
1. When reference fails, identify the issue:
   - Resource doesn't exist?
   - Output path wrong?
   - Dependency not connected?
2. Use dependency-resolver to find available outputs
3. Guide to correct reference syntax

## Example Workflows

**Secrets:** User: "Store DB password" → Create as secret → Show usage: `${secrets.db_password}` → Note encryption

**Environment Overrides:** User: "Prod needs more replicas" → Use overrides (not variables) → Override only `replicas` field → Keep rest as default

**Output References:** User: "Reference postgres host" → Use dependency-resolver → Show: `${postgres.db-name.out.attributes.host}` → Explain format

## Key Principles

**Security First:** Always use secrets for sensitive data. Guide users away from plain-text credentials.

**Environment Progression:** Help users test in dev, validate in staging, deploy to prod. Don't skip environments for critical changes.

**Minimal Configuration:** Only override what needs to differ. Don't duplicate entire configurations per environment.

**Reference Validation:** Check that output expressions are valid before deployment. Catch broken references early.

**Change Awareness:** When updating shared configuration, understand blast radius. Warn if changes affect multiple resources.

**Clear Syntax:** When guiding ${...} syntax, be precise. Small syntax errors break deployments.

## Configuration Patterns

**Project-Level Defaults:**
Set at project level, used by all environments unless overridden.
Use for: common configs, non-sensitive defaults, shared settings

**Environment-Specific Overrides:**
Override only what differs per environment.
Use for: environment URLs, resource sizing, feature flags

**Secrets:**
Always encrypted, never displayed, injected at runtime.
Use for: passwords, API keys, certificates, tokens

**Output References:**
Dynamic values from deployed resources.
Use for: connecting resources, avoiding hardcoded values

## Coordination

**Works with:**
- **Infrastructure Management skill**: Resources reference variables and outputs
- **dependency-resolver**: Validates output expressions and dependencies
- **K8s Operations skill**: Configuration changes trigger re-deployments

**Before deployment:** Validate all references and environment-specific values
**After updates:** Note that resources need re-deployment to pick up changes
