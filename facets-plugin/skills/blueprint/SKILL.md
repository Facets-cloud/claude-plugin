---
name: blueprint
description: Design and manage Facets infrastructure blueprints using Raptor CLI. Use when user mentions blueprint, resource, deployment, architecture, infrastructure, environment, or raptor commands.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Blueprint Design & Management

You architect Facets blueprints using Raptor CLI via Bash. All operations use `raptor` commands only.

## Subagent Delegation

For executing raptor commands, delegate to the **`/raptor`** subagent skill. Invoke `/raptor <task>` for any raptor CLI operation. The raptor subagent runs in an isolated fork, executes the commands, and returns structured results.

## Understanding Raptor CLI

Raptor operates on **projects** containing **resources** deployed across **environments**. Resources are infrastructure components (services, databases, networks) defined in JSON with dependencies via `${type.name.out.field}` references.

**Conventions:**
- Prefer long flags: `--project NAME`, `--environment NAME`
- Use `-o json` for parsing where supported
- Resource IDs: `type/name` (e.g., `service/api`, `postgres/mydb`)

## Core Operations

### Discovery
```bash
raptor get projects -o json
raptor get resources --project PROJECT -o json
raptor get environments --project PROJECT -o json
raptor get releases --project PROJECT --environment ENV -o json
raptor get variables --project PROJECT -o json
```

### Schema & Dependencies
```bash
raptor get resource-type-schema TYPE/FLAVOR/VERSION
raptor get resource-type-inputs TYPE/FLAVOR/VERSION
raptor get resource-type-outputs TYPE/FLAVOR/VERSION
raptor get resource-type-mappings PROJECT_TYPE               # List available modules
raptor get resource-output-expressions --project PROJECT     # All ${...} expressions
```

Check schema to know structure; check inputs to know dependencies.

### Resource Management
```bash
raptor apply -f resource.json --project PROJECT
raptor apply -f resource.json --project PROJECT --dry-run    # Validate only
raptor delete resource --project PROJECT TYPE/NAME
```

Resource structure:
```json
{
  "kind": "service",
  "flavor": "k8s",
  "version": "0.2",
  "metadata": {"name": "SERVICE_NAME"},
  "inputs": {
    "cloud_account": {
      "resource_type": "cloud_account",
      "resource_name": "my-aws",
      "output_name": "default"
    }
  },
  "spec": {
    "env": {
      "DB_HOST": "${TYPE.NAME.out.ATTRIBUTE_PATH}"
    }
  }
}
```

### Environment Overrides
```bash
raptor get resource-overrides --project PROJECT --environment ENV TYPE/NAME -o json
raptor set resource-overrides --project PROJECT --environment ENV -f overrides.json TYPE/NAME
```

Overrides customize resources per environment (replicas, memory, domains). Only include changed fields:
```json
{
  "spec": {
    "runtime": {"autoscaling": {"min": 3, "max": 10}}
  }
}
```

### Variables & Secrets
```bash
raptor get variables --project PROJECT
raptor get variable VARIABLE_NAME --project PROJECT
raptor create variable VARIABLE_NAME --project PROJECT --value "VALUE"
raptor create variable SECRET_NAME --project PROJECT --value "secret" --secret
raptor set variable VARIABLE_NAME --project PROJECT --value "NEW_VALUE"
```

### Deployment
```bash
raptor create release --project PROJECT --environment ENV -w              # Full release
raptor create release --project PROJECT --environment ENV --plan -w       # Dry-run (plan only)
raptor create release --project PROJECT --environment ENV --target TYPE/NAME -w  # Selective
raptor create release --project PROJECT --environment ENV --force -w      # Force
raptor logs release --project PROJECT --environment ENV RELEASE_ID
raptor logs release --project PROJECT --environment ENV -f RELEASE_ID     # Stream/follow
raptor get resource-outputs --project PROJECT --environment ENV TYPE/NAME -o json
raptor get resource-status --project PROJECT --environment ENV TYPE/NAME
```

**Release Options:**
- `--plan` - Create plan (dry-run, no apply)
- `--target TYPE/NAME` - Selective release (repeatable)
- `-w, --wait` - Wait for completion and tail logs
- `--force` - Force release even if no changes
- `--allow-destroy` - Allow resource destruction
- `--with-refresh` - Refresh Terraform state first
- `-m "message"` - Add comment/changelog

### Artifact Management
```bash
raptor create artifact --project PROJECT --image IMAGE_URI --tag TAG
raptor set artifact-uri --project PROJECT --environment ENV --image IMAGE_URI --tag TAG
```

### Auth & Permissions
```bash
raptor auth whoami
raptor auth can-i ACTION RESOURCE_TYPE --project PROJECT
```

### Output Formatting
All commands support: `-o table` (default), `-o wide`, `-o json`, `-o yaml`

## Architecture Patterns

**Microservices:** Each service owns its data. Services reference dependencies:
```json
"env": {
  "DB": "${TYPE.NAME.out.ATTRIBUTE_PATH}",
  "CACHE": "${TYPE.NAME.out.ATTRIBUTE_PATH}"
}
```

**Three-Tier:** Frontend -> API -> Database. Linear dependency chain.

**Event-Driven:** Services connect to message bus (Kafka), not directly to each other.

## Workflow

1. **Discover** - List projects, resources, environments
2. **Inspect schemas** - Get resource type schemas and inputs before creating resources
3. **Validate module availability** - Check resource-type-mappings for project type
4. **Apply resources** - Use `--dry-run` first, then apply
5. **Set overrides** - Environment-specific customization
6. **Deploy** - Plan first (`--plan`), then release with `-w` to monitor
7. **Monitor** - Check logs and resource outputs

## Key Principles

- Always fetch schemas/inputs; never guess resource structure
- Use `raptor get resource-output-expressions` for valid `${...}` references
- Plan before apply (`--plan` flag)
- Monitor deployments with `-w` flag
- Keep overrides minimal; base config should be broadly valid
- Reference outputs with `${type.name.out.field}` syntax
