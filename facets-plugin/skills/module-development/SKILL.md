---
name: facets-module
description: Create and manage Facets IaC modules and standard Terraform modules. Use when user mentions facets module, iac module, terraform module, facets.yaml, tf module, or module development. Covers both Facets-enhanced modules (facets.yaml + Terraform) and standard Terraform modules (HashiCorp best practices).
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Module Development Guide

Create production-ready Terraform modules — either **Facets IaC modules** (enhanced with facets.yaml for the Facets platform) or **standard Terraform modules** (HashiCorp best practices).

## Quick Decision: Facets vs Standard Module

```
  Is this module for the Facets platform?
       |
  +----+----+
  |         |
 YES        NO
  |         |
  v         v
 FACETS    STANDARD
 MODULE    TERRAFORM
 |         MODULE
 |         |
 |         +-> versions.tf (with required_providers)
 |         +-> variables.tf (standard vars)
 |         +-> main.tf
 |         +-> outputs.tf (output blocks)
 |         +-> README.md
 |
 +-> facets.yaml (identity, spec, inputs, outputs)
 +-> variables.tf (instance, instance_name, environment, inputs)
 +-> main.tf (NO provider blocks)
 +-> outputs.tf (locals only, NO output blocks)
 +-> versions.tf (terraform version only, NO provider versions)
```

---

## PART 1: FACETS MODULE DEVELOPMENT

### What is a Facets Module?

A Terraform module enhanced with `facets.yaml` metadata that:
- Defines a developer-friendly DSL (the `spec`)
- Declares typed inputs/outputs for inter-module connectivity
- Controls UI rendering for the Facets portal
- Enables automatic provider passing between modules

### Key Terminology

| Term | Description |
|------|-------------|
| **Intent (Kind)** | Technology/purpose (e.g., `postgres`, `service`, `kubernetes_cluster`) |
| **Flavor** | Implementation variant (e.g., `aws`, `gcp`, `k8s`) |
| **Version** | Semantic version (always quoted: `"1.0"`) |
| **Output Type** | JSON schema contract for module outputs |
| **Spec** | Developer-facing configuration DSL |

### Module Structure

```
my-module/
  facets.yaml          # Module metadata + schema (REQUIRED)
  variables.tf         # Standard Facets variables (REQUIRED)
  main.tf              # Terraform resources (REQUIRED)
  outputs.tf           # output_attributes + output_interfaces locals (REQUIRED)
  versions.tf          # Terraform version only (OPTIONAL)
```

### Critical Rules

| Rule | Reason |
|------|--------|
| **No provider blocks** | Providers come from inputs automatically |
| **No provider version constraints** | Versions defined in output type schemas |
| **No output blocks** | Use `local.output_attributes` and `local.output_interfaces` |
| **Use `lookup()` with defaults** | Never use `try()` |
| **`prevent_destroy = true`** | For stateful resources (databases, storage) |
| **Maps over arrays in spec** | Arrays break environment override deep merge |

### Development Workflow

```
  +----------+    +----------+    +----------+    +----------+    +---------+
  | 1. Design|    | 2. Write |    | 3. Valid |    | 4. Upload|    |5. Publi |
  | intent,  |--->| facets.  |--->| terraform|--->| raptor   |--->| raptor  |
  | flavor,  |    | yaml +   |    | init,    |    | create   |    | publish |
  | outputs  |    | .tf files|    | validate |    | iac-mod  |    |         |
  +----------+    +----------+    +----------+    +----------+    +---------+
```

### Subagent Delegation

For ALL raptor CLI operations (querying schemas, uploading modules, publishing), delegate to the **`/raptor`** subagent skill. Invoke `/raptor <task>` to execute raptor commands in an isolated fork.

#### Step 1: Survey & Design

Delegate to `/raptor`:
```
/raptor list resource-type-mappings for PROJECT_TYPE and get output-type @namespace/name
/raptor download iac-module TYPE/FLAVOR/VERSION to ./reference/
```

#### Step 2: Write facets.yaml

```yaml
intent: postgres
flavor: aws
version: "1.0"
description: |
  Creates a managed PostgreSQL database on AWS RDS
clouds:
  - aws

inputs:
  cloud_account:
    type: "@facets/aws_cloud_account"
    optional: false
    displayName: AWS Cloud Account
    providers:
      - aws
  network:
    type: "@facets/vpc-details"
    optional: false
    displayName: VPC Network

outputs:
  default:
    type: "@outputs/postgres"
    title: PostgreSQL Database

spec:
  title: PostgreSQL Configuration
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

sample:
  kind: postgres
  flavor: aws
  version: "1.0"
  disabled: false
  spec:
    version: "15"    # Only fields with defaults
```

#### Step 3: Write variables.tf

```hcl
variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      version = string
    })
  })
}

variable "instance_name" {
  type        = string
  description = "Unique architectural name from blueprint"
}

variable "environment" {
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  type = object({
    cloud_account = object({
      attributes = object({
        aws_region   = string
        aws_iam_role = string
      })
    })
    network = object({
      attributes = object({
        vpc_id    = string
        subnet_id = string
      })
    })
  })
}
```

#### Step 4: Write main.tf

```hcl
locals {
  name = "${var.instance_name}-${var.environment.unique_name}"
}

resource "aws_db_instance" "this" {
  identifier     = local.name
  engine         = "postgres"
  engine_version = var.instance.spec.version
  # ... more config

  lifecycle {
    prevent_destroy = true
  }
}
```

#### Step 5: Write outputs.tf (locals only, NO output blocks)

```hcl
locals {
  output_attributes = {
    db_id   = aws_db_instance.this.id
    db_arn  = aws_db_instance.this.arn
    secrets = ["password"]
  }

  output_interfaces = {
    primary = {
      host              = aws_db_instance.this.address
      port              = tostring(aws_db_instance.this.port)
      username          = aws_db_instance.this.username
      password          = aws_db_instance.this.password
      connection_string = "postgres://${aws_db_instance.this.address}:${aws_db_instance.this.port}"
      secrets           = ["password", "connection_string"]
    }
  }
}
```

#### Step 6: Validate & Upload

```bash
# Validate locally
terraform init
terraform validate
terraform fmt -check

# Upload as preview
raptor create iac-module -f ./my-module --auto-create

# Test in testing project
raptor create release --project testing-project --environment dev --plan -w

# Publish when ready
raptor publish iac-module TYPE/FLAVOR/VERSION
```

### Raptor Commands Reference

```bash
# Output types
raptor get output-type @namespace/name -o json
raptor create output-type @namespace/name -f schema.json

# Module management
raptor get iac-module TYPE/FLAVOR/VERSION
raptor create iac-module -f MODULE_DIR --auto-create    # Upload
raptor create iac-module -f MODULE_DIR --dry-run        # Validate
raptor publish iac-module TYPE/FLAVOR/VERSION            # Publish
raptor delete iac-module TYPE/FLAVOR/VERSION

# Project types
raptor get resource-type-mappings PROJECT_TYPE
raptor create resource-type-mapping PROJECT_TYPE --resource-type TYPE/FLAVOR
```

For complete facets.yaml reference, spec schema design, UI extensions, provider passing, and output type schemas, see [reference.md](reference.md).

---

## PART 2: STANDARD TERRAFORM MODULE DEVELOPMENT

For non-Facets Terraform modules following HashiCorp best practices.

### Module Structure

```
module_name/
  main.tf           # Primary resources
  variables.tf      # Input variables with validation
  outputs.tf        # Output values (standard output blocks)
  versions.tf       # Terraform + provider version constraints
  README.md         # Documentation
  examples/
    basic/
      main.tf       # Usage example
```

### Workflow

1. **Gather requirements** - What to build, which cloud, inputs/outputs
2. **Research** - Check Terraform Registry for existing modules
3. **Implement** - Write files following conventions below
4. **Validate** - `terraform init && terraform validate && terraform fmt -check`
5. **Test** - Create examples, run `terraform plan`
6. **Document** - README with usage, inputs, outputs

### versions.tf

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}
```

**IMPORTANT:** Never define `provider` blocks in modules. Let the root module configure providers.

### variables.tf

Always include descriptions, types, defaults where sensible, and validation:

```hcl
variable "name" {
  description = "Name for the resource"
  type        = string
  validation {
    condition     = length(var.name) > 0 && length(var.name) <= 64
    error_message = "Name must be between 1 and 64 characters."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```

### main.tf

```hcl
locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
  name_prefix = "${var.name}-${var.environment}"
}

resource "aws_s3_bucket" "main" {
  bucket = "${local.name_prefix}-bucket"
  tags   = local.common_tags
}
```

### outputs.tf (standard output blocks)

```hcl
output "bucket_id" {
  description = "The S3 bucket ID"
  value       = aws_s3_bucket.main.id
}

output "bucket_arn" {
  description = "The S3 bucket ARN"
  value       = aws_s3_bucket.main.arn
}

output "connection_string" {
  description = "Database connection string"
  value       = "host=${aws_db_instance.main.endpoint}"
  sensitive   = true
}
```

### Common Patterns

**Conditional creation:**
```hcl
resource "aws_s3_bucket" "main" {
  count  = var.create_bucket ? 1 : 0
  bucket = var.name
}
```

**Map-based resources (for_each):**
```hcl
resource "aws_s3_bucket" "main" {
  for_each = var.buckets
  bucket   = each.key
}
```

**Dynamic blocks:**
```hcl
dynamic "ingress" {
  for_each = var.ingress_rules
  content {
    from_port   = ingress.value.port
    to_port     = ingress.value.port
    protocol    = ingress.value.protocol
    cidr_blocks = ingress.value.cidr_blocks
  }
}
```

### Anti-Patterns

| Bad | Good |
|-----|------|
| Hardcoded values | Use variables |
| No descriptions | Always add descriptions |
| Provider blocks in modules | Define in root only |
| Secrets in code | Variables marked sensitive |
| `try()` for optionals | `lookup()` with defaults |
| No validation blocks | Add validation |
| No lifecycle rules | `prevent_destroy` for stateful |
| Arrays in Facets spec | Maps with patternProperties |

---

## Universal Best Practices

1. **Requirements first** - Understand before coding
2. **Research existing** - Check registry/reference modules
3. **Show code before writing** - Get user approval
4. **Validate always** - `terraform init`, `validate`, `fmt`
5. **Sensitive outputs** - Mark appropriately
6. **Lifecycle rules** - `prevent_destroy` for stateful resources
7. **Consistent naming** - `${name}-${environment}` pattern
8. **Documentation** - README for standard, facets.yaml sample for Facets
