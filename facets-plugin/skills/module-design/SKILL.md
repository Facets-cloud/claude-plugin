---
name: module-design
description: Decision guide for bundling vs separating infrastructure into Facets modules. Use when user asks about module design, bundling, separating resources, or structuring Terraform modules for Facets.
---

# Facets Module Design Decision Guide

A visual workflow for deciding when to bundle vs separate infrastructure entities into Facets modules.

## Decision Workflow

```
                              +---------------------+
                              |  START: New Entity  |
                              |  (e.g., subnet, DB, |
                              |   node group, SG)   |
                              +----------+----------+
                                         |
                                         v
                    +----------------------------------------+
                    |  Is this entity CONSUMED/REFERENCED    |
                    |  by MULTIPLE other modules?            |
                    |                                        |
                    |  Examples:                             |
                    |  - Database used by many services      |
                    |  - Domain zone used by many ingresses  |
                    |  - VPC used by EKS, RDS, ElastiCache   |
                    +--------------------+-------------------+
                                         |
                         +---------------+---------------+
                         |                               |
                        YES                              NO
                         |                               |
                         v                               v
          +--------------------------+    +---------------------------------+
          |     SEPARATE MODULE      |    |  Can this entity EXIST          |
          |                          |    |  MEANINGFULLY without parent?   |
          |  - Gets own output type  |    |                                 |
          |  - Appears in blueprint  |    |  Examples:                      |
          |  - Enables dropdowns     |    |  - Subnet without VPC? NO       |
          |                          |    |  - Node group without EKS? NO   |
          |  Examples:               |    |  - Route table without VPC? NO  |
          |  - postgres/rds          |    |  - Database without VPC? YES    |
          |  - domain/route53        |    +-----------------+---------------+
          |  - network/aws-vpc       |                      |
          +--------------------------+          +-----------+-----------+
                                                |                       |
                                                NO                     YES
                                                |                       |
                                                v                       v
                             +------------------------+   +---------------------------+
                             |   BUNDLE INTO PARENT   |   |  Is this a SINGLETON      |
                             |                        |   |  per cluster/project?     |
                             |  - Part of parent's    |   |                           |
                             |    Terraform           |   |  Examples:                |
                             |  - No separate output  |   |  - ALB Controller: YES    |
                             |  - User never sees it  |   |  - Cert-Manager: YES      |
                             |                        |   |  - Cloud Account: YES     |
                             |  Examples:             |   |  - Security Group: NO     |
                             |  - Subnet -> VPC       |   +------------+--------------+
                             |  - Node Group -> EKS   |                |
                             |  - IGW/NAT -> VPC      |    +-----------+-----------+
                             |  - Route Table -> VPC   |    |                       |
                             |  - Param Group -> RDS   |   YES                      NO
                             +------------------------+    |                       |
                                                           v                       v
                                            +------------------------+  +------------------------+
                                            |   SEPARATE MODULE      |  |  Is DUPLICATION        |
                                            |   (Singleton)          |  |  cheaper than SHARING? |
                                            |                        |  |                        |
                                            |  - One per cluster     |  |  Cost = complexity of  |
                                            |  - Often has no spec   |  |  wiring + maintenance  |
                                            |  - Enables others      |  |                        |
                                            |                        |  |  Examples:             |
                                            |  Examples:             |  |  - Security Group: YES |
                                            |  - alb-controller      |  |  - IAM Role: DEPENDS   |
                                            |  - cert-manager        |  |  - KMS Key: NO         |
                                            |  - external-dns        |  +----------+-------------+
                                            |  - cloud_account       |             |
                                            +------------------------+  +----------+-----------+
                                                                        |                      |
                                                                       YES                     NO
                                                                        |                      |
                                                                        v                      v
                                                       +-------------------------+  +---------------------+
                                                       |  BUNDLE (Duplicated)    |  |  SEPARATE MODULE    |
                                                       |                         |  |                     |
                                                       |  - Each consumer gets   |  |  - Shared resource  |
                                                       |    its own copy         |  |  - Referenced by    |
                                                       |  - Simpler than sharing |  |    multiple modules |
                                                       |  - No cross-wiring      |  |                     |
                                                       |                         |  |  Examples:          |
                                                       |  Examples:              |  |  - kms/aws          |
                                                       |  - SG per service       |  |  - iam_role/aws     |
                                                       |  - Param group per DB   |  |    (if shared)      |
                                                       +-------------------------+  +---------------------+
```

## Relationship Types

```
  COMPOSITION (1:1 or 1:N owned)          REFERENCE (N:1 consumer)
  +-----------------------------+         +-----------------------------+
  |  Parent OWNS children       |         |  Consumer USES provider     |
  |  Children die with parent   |         |  Provider has independent   |
  |                             |         |  lifecycle                  |
  |  +-------+                  |         |                             |
  |  |  VPC  |                  |         |  +---------+   +---------+  |
  |  +---+---+                  |         |  |Service A|   |Service B|  |
  |      | owns                 |         |  +----+----+   +----+----+  |
  |  +---+---+-------+         |         |       |  references |       |
  |  v       v       v         |         |       +------+------+       |
  | Subnet  IGW    Route       |         |              v              |
  |                             |         |        +----------+         |
  |  -> BUNDLE into VPC         |         |        | Database |         |
  +-----------------------------+         |        +----------+         |
                                          |                             |
                                          |  -> SEPARATE module         |
                                          +-----------------------------+

  SINGLETON (1 per cluster)               CHEAP DUPLICATABLE
  +-----------------------------+         +-----------------------------+
  |  Enables other resources    |         |  Could share, but simpler   |
  |  One instance per cluster   |         |  to duplicate per consumer  |
  |                             |         |                             |
  |      +--------------+       |         |  +---------+   +---------+  |
  |      | ALB Controller|      |         |  |Service A|   |Service B|  |
  |      +--------------+       |         |  |  +---+  |   |  +---+  |  |
  |             |               |         |  |  |SG |  |   |  |SG |  |  |
  |    +--------+--------+     |         |  |  +---+  |   |  +---+  |  |
  |    v        v        v     |         |  +---------+   +---------+  |
  |  ALB-1   ALB-2    ALB-3   |         |                             |
  |                             |         |  -> BUNDLE copy per module  |
  |  -> SEPARATE module         |         +-----------------------------+
  +-----------------------------+
```

## Wiring Decision

```
  +----------------------------------------------------------------------+
  |                    Does module need PROVIDER?                         |
  |                    (aws, kubernetes, helm, etc.)                      |
  +-----------------------------------+----------------------------------+
                                      |
                      +---------------+---------------+
                     YES                              NO
                      |                               |
                      v                               v
       +-------------------------+    +------------------------------------+
       |  Use 'inputs' section   |    |  Does spec field need TYPE         |
       |  in facets.yaml         |    |  VALIDATION + dropdown UX?         |
       |                         |    +------------------+-----------------+
       |  inputs:                |                       |
       |    cloud_account:       |       +---------------+---------------+
       |      type: "@.../aws"   |      YES                              NO
       |      providers:         |       |                               |
       |        - aws            |       v                               v
       +-------------------------+  +--------------------+  +--------------------+
                                    | Use x-ui-output-   |  | User wires via     |
                                    | type in spec       |  | ${} in blueprint   |
                                    |                    |  |                    |
                                    | service:           |  | env:               |
                                    |   type: string     |  |   DB_HOST: "${...}"|
                                    |   x-ui-output-type:|  |                    |
                                    |     "@.../k8s-svc" |  | (Not module design |
                                    +--------------------+  |  concern)          |
                                                            +--------------------+
```

## Example: AWS EKS Stack

```
   DISCOVERED                           MODULE DESIGN
   ----------                           -------------

   - AWS Account credentials    -->     cloud_account/aws (SINGLETON)
                                              |
   - VPC                        -->     network/aws-vpc (SEPARATE - referenced)
   - 10 Subnets                 -->          | BUNDLED
   - Internet Gateway           -->          | BUNDLED
   - NAT Gateway                -->          | BUNDLED
   - Route Tables               -->          | BUNDLED
                                              |
   - EKS Cluster                -->     kubernetes_cluster/eks (SEPARATE)
   - Node Groups (ASG)          -->          | BUNDLED
   - Cluster Security Group     -->          | BUNDLED
   - Node Security Groups       -->          | BUNDLED
                                              |
   - Route53 Zone               -->     domain/route53 (SEPARATE - referenced)
   - ACM Certificate            -->          | BUNDLED
                                              |
   - ALB Controller             -->     ingress/alb-controller (SINGLETON)
                                              |
   - Load Balancers             -->     (Created by k8s Services - NO MODULE)

   - Loki S3 Bucket             -->     loki/aws
                                              | BUNDLED internally

   - TF State Bucket            -->     terraform_backend/aws (BOOTSTRAP)
   - DynamoDB Lock Table        -->          | BUNDLED
```

## Good Blueprint vs Bad Blueprint

**Good** - Each resource = meaningful architectural concept:
```yaml
- cloud_account/aws: main
- network/aws-vpc: main
- kubernetes_cluster/eks: main
- domain/route53: apps
- ingress/alb-controller: main
- service/k8s: my-app
- postgres/rds: my-db
```

**Bad** - Infrastructure plumbing exposed:
```yaml
- vpc/aws: main
- subnet/aws: public-2a
- subnet/aws: public-2b
- subnet/aws: private-2a-1
- security-group/aws: eks-cluster
- security-group/aws: eks-nodes
- eks-cluster/aws: main
- eks-nodegroup/aws: spot
# ... 20 more primitives
```

## Quick Reference

| Relationship | Description | Decision | Example |
|--------------|-------------|----------|---------|
| **Composition** | Child owned by parent, dies with parent | BUNDLE | Subnet -> VPC |
| **Reference** | Consumer uses provider, independent lifecycle | SEPARATE | Service -> Database |
| **Singleton** | One per cluster, enables others | SEPARATE | ALB Controller |
| **Cheap Duplicatable** | Could share but simpler to duplicate | BUNDLE copy | SG per service |

## Key Principles

1. **Bundle composition relationships** - If it can't exist without the parent, bundle it
2. **Separate reference relationships** - If multiple consumers need it, make it a module
3. **Minimize override-only fields** - Data should flow via inputs, not be repeated
4. **Blueprint comprehensibility** - Each resource should be a meaningful concept
5. **Maps over arrays** - Use `patternProperties` for deep merge support
