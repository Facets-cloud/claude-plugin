# Module Technical Reference

Detailed technical specifications for module structure, schemas, wiring, and conventions. Consult this when writing module code — these are the platform's rules, not suggestions.

## Module Configuration (facets.yaml)

Every Facets module has a `facets.yaml` that declares its identity, dependencies, outputs, and configuration schema.

```yaml
# === IDENTITY ===
intent: postgres                    # Kind/technology (REQUIRED)
flavor: ovh                         # Implementation variant (REQUIRED)
version: "1.0"                      # Semantic version, MUST be quoted (REQUIRED)
description: |                      # Human-readable description (REQUIRED)
  Creates a managed PostgreSQL database on OVH Cloud
clouds:                             # Compatible clouds (REQUIRED for now)
  - aws                             # Valid: aws, azure, gcp, kubernetes

# === INPUTS (Dependencies) ===
inputs:
  cloud_account:                    # Input name (used in var.inputs.cloud_account)
    type: "@facets/aws_cloud_account"  # Output type this input accepts
    optional: false                 # Whether required
    displayName: AWS Cloud Account  # UI display name
    description: AWS cloud account for provisioning
    providers:                      # Providers this input supplies
      - aws
  network:                          # Data-only input (no providers)
    type: "@mycompany/vpc-details"
    optional: false
    displayName: VPC Network
    description: Network configuration

# === OUTPUTS ===
outputs:
  default:                          # REQUIRED: primary output for UI autocomplete
    type: "@outputs/postgres"       # Output type contract
    title: PostgreSQL Database
    providers:                      # If exposing providers
      kubernetes:
        source: hashicorp/kubernetes
        version: 2.23.0
        attributes:
          host: attributes.cluster_endpoint
          cluster_ca_certificate: attributes.cluster_ca_certificate

  attributes:                       # OPTIONAL: subset for x-ui-output-type wiring
    type: "@mycompany/postgres_attributes"
    title: PostgreSQL Attributes

  attributes.read_only_iam_policy_arn:  # OPTIONAL: nested path for cross-module reuse
    type: "@outputs/iam_policy_arn"
    title: Read-Only IAM Policy

# === ARTIFACT INPUTS (for deployable modules) ===
artifact_inputs:
  primary:
    attribute_path: spec.release.image   # Path in spec for artifact URI
    artifact_type: docker_image          # "docker_image" or "freestyle"

# === SPEC SCHEMA ===
spec:
  title: PostgreSQL Configuration
  description: Configure your PostgreSQL database
  type: object
  properties:
    version:
      type: string
      title: PostgreSQL Version
      enum: ["14", "15", "16"]
      default: "15"
  required:
    - version
  x-ui-order:
    - version

# === SAMPLE RESOURCE ===
sample:
  kind: postgres
  flavor: ovh
  version: "1.0"
  disabled: false
  spec:
    version: "15"    # ONLY include fields with defaults defined
```

## Wiring Methods

### Method 1: Inputs (Compile-Time Dependency)

```yaml
inputs:
  kubernetes_details:
    type: "@facets/ovh-kubernetes"
    providers:
      - kubernetes
      - helm
```
- Creates hard dependency edge in blueprint graph
- Module receives data via `var.inputs.<name>`
- Use for: providers, required infrastructure dependencies

### Method 2: `${}` Expressions (Runtime Reference)

```yaml
spec:
  env:
    DB_HOST: "${postgres.petsdb.out.interfaces.writer.host}"
```
- No compile-time dependency declared
- Expression stored in spec, resolved at deployment
- Use for: optional references, dynamic wiring between services

### Reference Syntax

```
${<kind>.<resource_name>.out.<attributes|interfaces>.<path>}
${postgres.main-db.out.interfaces.writer.host}
${service.petclinic.out.attributes.service_name}
${blueprint.self.artifacts.<artifact_name>}
${blueprint.self.secrets.<secret_name>}
${blueprint.self.variables.<variable_name>}
```

## Terraform File Conventions

### variables.tf

The structure of `var.inputs.<name>` is determined by the output type schema being consumed. Always query the output type to understand the shape.

```hcl
variable "inputs" {
  type = object({
    network = object({
      attributes = object({
        network_id   = string
        region       = string
        db_subnet_id = string
      })
    })
  })
}
```

`var.instance.spec` mirrors `facets.yaml spec.properties`.

**Exception for x-ui-output-type fields:**

| Location | Type | Reason |
|----------|------|--------|
| facets.yaml spec | `type: string` | Stores `${...}` expression |
| variables.tf | `object({...})` | Expression resolves to actual object at runtime |

### outputs.tf

Two output categories:

| Field | Purpose | Use For |
|-------|---------|---------|
| `output_attributes` | All non-network outputs | IDs, ARNs, names, config values |
| `output_interfaces` | Network endpoints only | host, port, username, password |

The `secrets` key marks sensitive fields:
```hcl
output_attributes = {
  api_key = var.api_key
  secrets = ["api_key"]    # Lists sensitive sibling fields
}

output_interfaces = {
  primary = {
    host     = "db.example.com"
    password = "secret123"
    secrets  = ["password"]
  }
}
```

### Resource Naming

```hcl
locals {
  name = "${var.instance_name}-${var.environment.unique_name}"  # Globally unique
}
```

### versions.tf

```hcl
terraform {
  required_version = ">= 1.5.0, < 2.0.0"
  # NO required_providers block — providers come through inputs
}
```

## Provider Passing

### Exposing Providers (in outputs)

```yaml
outputs:
  default:
    type: "@facets/kubernetes-details"
    providers:
      kubernetes:
        source: hashicorp/kubernetes
        version: 2.23.0
        attributes:
          host: attributes.cluster_endpoint
          cluster_ca_certificate: attributes.cluster_ca_certificate
      helm:
        source: hashicorp/helm
        version: 2.11.0
        attributes:
          kubernetes:
            host: attributes.cluster_endpoint
            cluster_ca_certificate: attributes.cluster_ca_certificate
```

### Consuming Providers (in inputs)

```yaml
inputs:
  kubernetes_details:
    type: "@facets/kubernetes-details"
    providers:
      - kubernetes
      - helm
```

### Provider Chain

```
cloud_account → network → kubernetes_cluster → service
     |              |            |                   |
    aws          (data)    kubernetes/helm    (uses both)
```

## Spec Schema Design

### Property Types

**String with enum:**
```yaml
version:
  type: string
  enum: ["14", "15", "16"]
  default: "15"
```

**Integer with range:**
```yaml
nodes_count:
  type: integer
  minimum: 1
  maximum: 10
  default: 3
```

**Map with patternProperties (ALWAYS prefer over arrays):**
```yaml
ports:
  type: object
  patternProperties:
    "^[a-zA-Z0-9_-]+$":
      type: object
      properties:
        port: { type: string }
        protocol: { type: string, enum: [tcp, udp] }
```

**Output type reference (for cross-resource wiring in UI):**
```yaml
s3_bucket:
  type: string
  x-ui-output-type: "@mycompany/s3_bucket_attributes"
```

### Deep Merge: Maps vs Arrays

Arrays are REPLACED entirely on override. Maps MERGE at key level. Always prefer maps.

Only use arrays when: order matters AND the field is never partially overridden (e.g., `command`, `args`).

## UI Extensions

| Extension | Purpose |
|-----------|---------|
| `x-ui-order` | Field display order in UI |
| `x-ui-toggle` | Collapsible section |
| `x-ui-visible-if` | Show field conditionally based on another field's value |
| `x-ui-overrides-only` | Field only appears in environment overrides (no base default) |
| `x-ui-override-disable` | Field cannot be overridden per environment |
| `x-ui-secret-ref` | Dropdown of project secrets |
| `x-ui-variable-ref` | Dropdown of project variables |
| `x-ui-output-type` | Dropdown of modules matching an output type |
| `x-ui-output` | Dropdown of output fields from a referenced resource |
| `x-ui-yaml-editor` | YAML editor for free-form maps |
| `x-ui-textarea` | Multi-line text input |
| `x-ui-editor` | Code editor widget |
| `x-ui-typeable` | Allow typing in dropdowns |
| `x-ui-dynamic-enum` | Options populated from another field's keys |
| `x-ui-compare` | Cross-field validation |
| `x-ui-artifact` | Attach artifact to this field |

### x-ui-visible-if

```yaml
readiness_port:
  type: string
  x-ui-visible-if:
    field: spec.health_checks.type
    values:
      - PortCheck
      - HttpCheck
```

In patternProperties, use `{{this}}` for the current key:
```yaml
certificate:
  x-ui-visible-if:
    field: spec.domains.{{this}}.custom_tls.enabled
    values: [true]
```

### x-ui-compare

```yaml
cpu:
  type: string
  x-ui-compare:
    field: spec.size.cpu_limit
    comparator: "<="
    x-ui-error-message: "CPU cannot exceed limit"
```

## Output Type Schemas

Output types are JSON Schema documents defining what a module exposes.

### Without providers
```json
{
  "properties": {
    "type": "object",
    "properties": {
      "attributes": {
        "type": "object",
        "properties": {
          "bucket_name": { "type": "string" },
          "bucket_arn": { "type": "string" }
        }
      },
      "interfaces": {
        "type": "object",
        "properties": {}
      }
    }
  },
  "providers": []
}
```

### With providers
```json
{
  "properties": {
    "type": "object",
    "properties": {
      "attributes": {
        "type": "object",
        "properties": {
          "aws_region": { "type": "string" },
          "aws_iam_role": { "type": "string" }
        }
      }
    }
  },
  "providers": [
    {
      "name": "aws",
      "source": "hashicorp/aws",
      "version": "5.0.0"
    }
  ]
}
```

### With interfaces
```json
{
  "properties": {
    "type": "object",
    "properties": {
      "attributes": {
        "type": "object",
        "properties": {
          "cluster_id": { "type": "string" }
        }
      },
      "interfaces": {
        "type": "object",
        "properties": {
          "primary": {
            "type": "object",
            "properties": {
              "host": { "type": "string" },
              "port": { "type": "string" },
              "username": { "type": "string" },
              "password": { "type": "string" },
              "connection_string": { "type": "string" }
            }
          }
        }
      }
    }
  },
  "providers": []
}
```

### Naming Conventions

```
@outputs/<intent>        # Standard outputs (postgres, redis, service)
@facets/<name>           # Facets platform types (aws_cloud_account)
@<company>/<name>        # Organization-specific types
```

## Module Quality Checklist

- [ ] `facets.yaml` has intent, flavor, version (quoted), description, clouds
- [ ] `spec` has properties, required fields, x-ui-order
- [ ] `inputs` declared for all dependencies with correct output types
- [ ] `outputs` has `default` with correct output type
- [ ] `sample` only includes fields that have defaults
- [ ] `variables.tf` has instance, instance_name, environment, inputs
- [ ] `main.tf` has resources with `prevent_destroy` for stateful resources
- [ ] `outputs.tf` defines `output_attributes` and `output_interfaces` locals
- [ ] NO provider blocks in module code
- [ ] NO required_providers in versions.tf
- [ ] NO output blocks (platform handles this)
- [ ] Output type schema matches actual output_attributes/output_interfaces structure
- [ ] Maps used instead of arrays in spec (for deep merge support)
- [ ] Resource names include `var.instance_name` and `var.environment.unique_name` for uniqueness
