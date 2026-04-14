# Infrastructure Context

> Customize this file with your organization's defaults.
> This is loaded alongside every skill, giving the agent awareness of your environment.

## Organization Defaults
- Cloud: AWS (us-east-1 primary)
- K8s: EKS 1.29
- IaC: Terraform with S3 backend
- CI/CD: GitHub Actions
- Secrets: AWS Secrets Manager
- Monitoring: Datadog
- Container Registry: ECR

## Naming Conventions
- Resources: {team}-{service}-{env}
- Namespaces: {team}-{env}
- Docker tags: {git-sha}-{timestamp}
- Terraform modules: modules/{provider}/{resource}

## Environments
- dev: auto-deploy on merge to main
- staging: manual promote from dev
- prod: requires approval gate + canary

## Compliance
- All changes via PR, no direct pushes
- Prod deployments require approval gate
- All secrets rotated every 90 days
- Container images scanned before deploy
