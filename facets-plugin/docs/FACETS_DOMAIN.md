# Facets Platform Domain Knowledge

**Purpose:** Cross-cutting platform knowledge shared by all skills and agents. Read this to understand fundamental Facets concepts, terminology, and architectural patterns.

---

## Platform Overview

Facets is a proprietary DevOps orchestration platform that manages and automates Terraform and Kubernetes operations. Users interact with Facets rather than directly with Terraform or Kubernetes.

**Key Principle:** Facets is an **orchestration layer** - users don't run terraform or kubectl commands directly.

---

## Platform Architecture

### Facets Hierarchy

```
Organization
  └── Project (Stack)
      └── Environment (Cluster)
          └── Resources (Services, Databases, etc.)
```

**Projects (Stacks):**
- Top-level organizational unit
- Contains multiple environments
- Manages blueprint configurations (JSON)
- All resource definitions live here

**Environments (Clusters):**
- Deployment targets (dev, staging, production)
- Each environment is a Kubernetes cluster
- Resources deployed per environment
- Can have environment-specific overrides

**Resources:**
- Infrastructure components (service, postgres, redis, etc.)
- Defined as JSON configurations
- Validated against schemas
- Deployed via releases

### Orchestration Layer

**How Facets Works:**
1. User creates/updates JSON resource configurations
2. Facets validates JSON against schemas
3. User triggers release
4. Facets generates Terraform code automatically
5. Facets executes Terraform via controlled release process
6. Facets manages Kubernetes deployments

**What Users DON'T Do:**
- ❌ Write Terraform/HCL code directly
- ❌ Run `terraform apply` manually
- ❌ Run `kubectl apply` for resource changes
- ❌ Edit Kubernetes manifests directly

**What Users DO:**
- ✅ Create JSON resource configurations
- ✅ Trigger releases through Facets
- ✅ Use raptor CLI for operations
- ✅ Let Facets handle Terraform/Kubernetes

---

## Proper Terminology

**Critical:** Use Facets terminology, not Terraform/Kubernetes terminology

| ✅ Use This | ❌ Not This | Context |
|------------|------------|---------|
| **Trigger a release** | "run terraform" | Deployment action |
| **Environment** | "cluster" | Deployment target |
| **Facets project** | "terraform workspace" | Top-level unit |
| **Resource configuration** | "terraform file" | Infrastructure definition |
| **Blueprint** | "terraform code" | Project's resource definitions |
| **Release** | "terraform apply" | Deployment execution |
| **Stack** | "project" | Alternative term for project |
| **Resource** | "kubernetes deployment" | When referring to Facets-managed infra |

**Terminology in Practice:**
- "Let's trigger a release to deploy these changes" ✅
- "Run terraform apply to deploy" ❌
- "Update the resource configuration for the service" ✅
- "Edit the terraform file" ❌

---

## Deployment Types

Facets supports multiple deployment workflows:

### RELEASE (Standard)
- **Purpose:** Full infrastructure deployment
- **Scope:** All resources in environment
- **Use when:** Standard infrastructure updates
- **Command:** `raptor create release -p PROJECT -e ENV`
- **Behavior:** Deploys all resource changes to environment

### HOTFIX (Selective)
- **Purpose:** Quick, targeted resource updates
- **Scope:** Specific selected resources
- **Use when:** Urgent fixes without full release
- **Access:** UI-driven, safe selective deployment
- **Behavior:** Deploys only selected resources

### CUSTOM (Advanced)
- **Purpose:** Direct terraform operations
- **Scope:** Operations team only
- **Use when:** Advanced scenarios requiring terraform access
- **Warning:** Bypasses Facets orchestration safeguards
- **Behavior:** Direct terraform command execution

### LAUNCH (Provisioning)
- **Purpose:** New environment creation
- **Scope:** Entire environment from scratch
- **Use when:** Setting up new environment
- **Behavior:** Provisions all required infrastructure

### PLAN (Dry-run)
- **Purpose:** Preview changes before deployment
- **Scope:** Same as RELEASE but no apply
- **Use when:** Validating changes before deployment
- **Behavior:** Runs terraform plan, shows diff

---

## Release Management

### Release Flags

**`--allow-destroy`**: Bypass Terraform prevent_destroy lifecycle rules
- **Use when:** Deleting/replacing resources with prevent_destroy=true
- **Why:** Avoids module modification and republishing
- **Facets approach:** Handle destruction safety at release level, not module level
- **Example:** `raptor create release -p PROJECT -e ENV --allow-destroy`
- **Never suggest:** Removing prevent_destroy from module code

**`--auto-approve`**: Skip approval prompt
- **Use when:** Automated pipelines, trusted changes
- **Warning:** Deploys immediately without review
- **Example:** `raptor create release -p PROJECT -e ENV --auto-approve`

**`-w` (wait)**: Wait for release to complete
- **Use when:** Need to monitor completion
- **Behavior:** Command blocks until release succeeds or fails
- **Example:** `raptor create release -p PROJECT -e ENV -w`

### Release Lifecycle

```
1. Configuration Update → JSON resource changes
2. Apply Configuration → raptor apply -f resource.json
3. Trigger Release → raptor create release
4. Terraform Generation → Facets generates .tf files
5. Terraform Execution → Facets runs terraform apply
6. Resource Deployment → Kubernetes resources created/updated
7. Status Monitoring → raptor get releases / logs
```

---

## Configuration Management

### JSON Configurations

**Facets Configuration Format:**
- Type-safe JSON validated against schemas
- Schema retrieved via `raptor get resource-type-schema`
- Facets converts JSON to Terraform automatically
- Changes validated before deployment

**Configuration Structure:**
```json
{
  "kind": "service",
  "flavor": "k8s",
  "version": "0.2",
  "metadata": {
    "name": "my-api"
  },
  "inputs": {
    "kubernetes_cluster": {
      "resource_type": "kubernetes_cluster",
      "resource_name": "prod-cluster",
      "output_name": "default"
    }
  },
  "spec": {
    "image": {
      "repository": "myapp",
      "tag": "v1.0.0"
    },
    "runtime": {
      "size": {
        "cpu": "500m",
        "memory": "1Gi"
      }
    }
  }
}
```

**Critical Configuration Rules:**
1. **Always validate against schema** - Don't invent fields
2. **Use proper output expressions** - `${resource_type.resource_name.out.field}`
3. **Never suggest direct Terraform** - Work through JSON configs
4. **Schema is source of truth** - Not assumptions or documentation

### Variables and Secrets

**Variables:**
- Plain-text configuration values
- Project-level defaults
- Environment-specific overrides
- Syntax: `${blueprint.self.variables.variable_name}`

**Secrets:**
- Encrypted sensitive values
- Never displayed in plaintext
- Injected at runtime
- Syntax: `${blueprint.self.secrets.secret_name}`

**Best Practices:**
- Use secrets for: passwords, API keys, tokens, certificates
- Use variables for: URLs, feature flags, non-sensitive config
- Set project defaults, override per environment only when needed

### Output Expressions

**Purpose:** Reference values from other resources dynamically

**Syntax:**
```
${resource_type.resource_name.out.field_path}
```

**Examples:**
```json
{
  "env": {
    "DB_HOST": "${postgres.main-db.out.attributes.host}",
    "DB_PORT": "${postgres.main-db.out.attributes.port}",
    "CACHE_URL": "${redis.cache.out.interfaces.url}"
  }
}
```

**Output Expression Rules:**
1. Must reference existing resource
2. Must use valid output path (from resource outputs)
3. Validates at release time, not configuration time
4. Dependency order automatically resolved by Terraform

---

## Raptor CLI Context

### Context Requirements

**Almost all raptor commands require context:**
- `-p PROJECT` - Which project (required for most commands)
- `-e ENV` - Which environment (required for environment-specific operations)

**Context Discovery:**
- Use `raptor-context-provider` agent to establish context automatically
- Agent handles project/environment selection intelligently
- Context persists for session

**Example Context Flow:**
```bash
# Without agent (manual)
raptor get projects
# Select project: "myapp"
raptor get environments -p myapp
# Select environment: "production"
raptor get resources -p myapp -e production

# With agent (automatic)
# Agent discovers projects, auto-selects if unambiguous
# Agent suggests environment based on recent activity
# All subsequent commands use established context
```

---

## Kubernetes Access

**Accessing Kubernetes via Facets:**

Facets manages Kubernetes clusters. To access kubectl:

```bash
# Download kubeconfig via Facets
raptor get kubeconfig -p PROJECT -e ENV -o ~/.kube/facets-env

# Use kubectl with Facets kubeconfig
export KUBECONFIG=~/.kube/facets-env
kubectl get pods
```

**Important:**
- Don't use kubectl for resource changes (use Facets releases)
- kubectl for debugging and inspection only
- Facets-managed resources reconciled by Terraform
- Manual kubectl changes overwritten by next release

---

## Module Development

### Facets Terraform Framework (FTF)

**Facets uses FTF for module development:**
- Modules defined with `facets.yaml` metadata
- Terraform code implements module logic
- Output types registered in control plane
- Modules versioned and published centrally

**Module Structure:**
```
my-module/
├── facets.yaml          # Module metadata (REQUIRED)
├── main.tf              # Terraform resources (REQUIRED)
├── variables.tf         # Input variables (REQUIRED)
├── outputs.tf           # Output definitions (REQUIRED)
├── README.md            # Documentation (RECOMMENDED)
└── versions.tf          # Provider versions (OPTIONAL)
```

**facets.yaml Example:**
```yaml
name: my-service
version: "1.0.0"
title: "My Service Module"
description: "Deploys service to Kubernetes"

intent:
  name: service
  output_type: "@myorg/service"
  cloud: aws

inputs:
  - name: kubernetes_cluster
    output_type: "@facets/kubernetes-cluster"
    optional: false

write_outputs:
  output_interfaces:
    url: "http://..."
  output_attributes:
    pod_count: "..."
```

---

## Common Anti-Patterns

**❌ Don't:**
1. Suggest writing Terraform/HCL code directly
2. Recommend manual terraform/kubectl commands for resource changes
3. Invent JSON configuration fields without checking schema
4. Use Kubernetes/Terraform terminology instead of Facets terms
5. Suggest removing prevent_destroy from modules
6. Bypass Facets orchestration layer

**✅ Do:**
1. Work through Facets JSON configurations
2. Trigger releases for all infrastructure changes
3. Validate configurations against schemas
4. Use proper Facets terminology
5. Use --allow-destroy flag for protected resource deletion
6. Respect Facets orchestration and safety mechanisms

---

## Integration Points

### Raptor CLI
- Primary command-line interface
- Handles all Facets operations
- Requires authentication (raptor login)
- Context-aware (-p PROJECT -e ENV)

### MCPs Available

**facets-module** (This plugin):
- Module development and validation
- Output type registration
- Module preview and testing
- FTF operations

**facets-control-plane** (Deprecated - use raptor CLI):
- Previously: Resource and project management
- Now: Use raptor CLI directly for better performance

**facets-ops** (External, may not be available):
- Kubeconfig management
- Deployment log fetching
- Terraform module analysis

---

## Key Takeaways for Agents

1. **Facets orchestrates everything** - Users interact with Facets, not raw Terraform/K8s
2. **Use Facets terminology** - "trigger release", "environment", "resource configuration"
3. **JSON configs are source of truth** - Always validate against schemas
4. **Context is critical** - Most operations require project and environment
5. **Releases are the deployment mechanism** - Not direct terraform/kubectl
6. **--allow-destroy for lifecycle protection** - Don't modify modules
7. **Output expressions connect resources** - `${type.name.out.field}` syntax
8. **Respect the orchestration layer** - Don't bypass Facets safeguards

---

## When in Doubt

1. **Check schemas**: `raptor get resource-type-schema INTENT/FLAVOR/VERSION`
2. **Use agents**: raptor-context-provider, schema-inspector, dependency-resolver
3. **Validate before deploy**: JSON configs must pass schema validation
4. **Follow Facets patterns**: Work through orchestration, don't bypass
5. **Use proper terminology**: Facets-specific terms, not Terraform/K8s terms
