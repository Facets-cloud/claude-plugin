# Infrastructure Resource Management

Intelligent orchestration for provisioning, configuring, and managing Facets infrastructure resources through the complete lifecycle.

## Prerequisites

**Platform Knowledge:** Read [FACETS_DOMAIN.md](../../docs/FACETS_DOMAIN.md) for Facets platform fundamentals.

This skill assumes understanding of:
- Facets orchestration layer and terminology
- Deployment types and release management
- Configuration management (JSON, schemas, output expressions)
- Release flags and lifecycle rules

## Domain

Infrastructure resource operations: discovery, schema exploration, configuration, provisioning, updates, dependency resolution, and lifecycle management.

## Capabilities

**Resource Intelligence:**
- Discover available resource types and understand their schemas
- Interpret complex schemas and guide configuration
- Resolve dependencies and output expressions
- Validate configurations before deployment

**Provisioning Workflows:**
- Create new infrastructure resources with proper inputs
- Update existing resource configurations
- Handle environment-specific overrides
- Manage resource deletion safely

**Deployment Orchestration:**
- Trigger releases for resource deployment
- Monitor deployment status and logs
- Handle deployment failures intelligently
- Coordinate multi-resource deployments

## Available Agents

- **raptor-context-provider** - Establish project/environment context (Haiku)
- **schema-inspector** - Interpret resource schemas into human-readable docs (Haiku)
- **resource-schema-interpreter** - Guide configuration based on schema (Haiku)
- **dependency-resolver** - Resolve resource dependencies and outputs (Sonnet)

## Intelligence Guidelines

**Context Awareness:**
Establish project/environment context early using raptor-context-provider. Cache context for session continuity. Don't repeatedly ask about project/environment.

**Schema-Driven Configuration:**
Use schema-inspector and resource-schema-interpreter to understand what's configurable rather than guessing. Let users know what's possible based on actual schema.

**Dependency Intelligence:**
Use dependency-resolver to understand resource relationships. Suggest missing dependencies. Validate output expressions before deployment.

**Progressive Refinement:**
Start with minimal valid configuration. Let users add complexity progressively. Don't overwhelm with all options upfront.

**Error Intelligence:**
When deployments fail, analyze logs intelligently. Distinguish between configuration errors, dependency issues, and infrastructure problems. Guide users to resolution.

## Raptor Commands

**Discovery:** `raptor get resource-types`, `raptor get resource-type-schema/inputs/outputs INTENT/FLAVOR/VERSION`

**Resources:** `raptor apply -f resource.json -p PROJECT`, `raptor get resources -p PROJECT [-e ENV]`, `raptor get resource-status`, `raptor delete resource`

**Deployment:** `raptor create release -p PROJECT -e ENV [--allow-destroy]`, `raptor get releases`, `raptor logs release RELEASE_ID`

**Configuration:** `raptor get resource-outputs`, `raptor get resource-output-expressions`, `raptor set resource-overrides`

## Workflow Intelligence

**Resource Creation:**
1. Understand what user wants to create
2. Use schema tools to understand configuration needs
3. Check dependencies with dependency-resolver
4. Guide configuration progressively
5. Apply and monitor deployment

**Resource Updates:**
1. Fetch current configuration
2. Understand desired changes
3. Use schema to validate changes
4. Apply updates and monitor

**Dependency Management:**
1. Detect output expressions in configuration
2. Use dependency-resolver to validate references
3. Suggest available outputs when needed
4. Ensure dependency order in deployments

**Error Handling:**
1. Analyze deployment logs intelligently
2. Distinguish error types (config, dependency, infra, lifecycle)
3. Suggest specific fixes based on error patterns
4. Guide users through resolution

**Common Error Patterns:**
- **Dependency errors:** Missing required inputs → check resource connections with dependency-resolver
- **Validation errors:** Schema violations → validate against schema using resource-schema-interpreter
- **Provider errors:** Cloud provider issues → check quotas, permissions, network access
- **Lifecycle prevent_destroy errors:** Terraform blocks destruction due to prevent_destroy
  - **Pattern:** "Resource has lifecycle.prevent_destroy set"
  - **Solution:** Use `raptor create release --allow-destroy` flag
  - **Never suggest:** Removing prevent_destroy from module (requires republish)
  - **Facets approach:** Handle destruction safety at release level, not module level

## Example Workflows

**Creating Resources:**
User: "Deploy postgres database" → Use schema-inspector for options → Ask flavor choice (RDS/CloudSQL/K8s) → Guide configuration → Check dependencies with dependency-resolver → Create and monitor

**Troubleshooting:**
User: "Service failing" → Get release logs → Analyze patterns (env vars, dependencies, limits) → Guide to fix → Verify and re-deploy

**Lifecycle Errors:**
User: "prevent_destroy error on deletion" → Recognize pattern → **Use** `--allow-destroy` flag → **Never suggest** module modification → Confirm before execution

## Key Principles

**Trust Agent Intelligence:** Agents are domain experts. Use them when their expertise is needed, trust their output.

**Progressive Disclosure:** Don't dump entire schema. Show what's needed when it's needed.

**Context Efficiency:** Establish context once, reuse throughout session. Don't be repetitive.

**Failure Intelligence:** When things fail, analyze and guide. Don't just report errors.

**Dependency Awareness:** Understand resource relationships. Validate connections before deployment.

**User Intent:** Focus on what user wants to achieve, not rigid processes. Adapt workflows to user's goal.
