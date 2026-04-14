# DevOps Skills Tool Registry

Maps each skill to the CLI tools, credentials, and install commands it needs.

## Requirements Matrix

| Skill | CLI Tools Needed | Env Vars / Creds Required | Install Command |
|-------|-----------------|--------------------------|-----------------|
| k8s-debug | kubectl | KUBECONFIG or ~/.kube/config | `tools/installers/kubectl.sh` |
| tf-review | terraform or tofu | Cloud provider creds (AWS/GCP/Azure) | `tools/installers/terraform.sh` |
| cloud-cost | aws cli and/or gcloud | AWS_PROFILE or GOOGLE_PROJECT | `tools/installers/cloud-cli.sh` |
| secrets-audit | gitleaks | (none — local scanning) | `tools/installers/gitleaks.sh` |
| docker-optimize | docker, trivy, dive | (none — local analysis) | `tools/installers/docker-tools.sh` |
| incident-rca | kubectl, aws/gcloud, jq | KUBECONFIG + cloud creds | (combines above) |

## Credential Setup Guides

### AWS

```bash
# Option 1: SSO (recommended)
aws configure sso
export AWS_PROFILE=your-profile

# Option 2: Static keys
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_REGION=us-east-1

# Option 3: Assume role
aws sts assume-role --role-arn arn:aws:iam::123:role/MyRole --role-session-name cli

# Verify
aws sts get-caller-identity
```

### GCP

```bash
# Application Default Credentials
gcloud auth application-default login
export GOOGLE_PROJECT=your-project-id

# Verify
gcloud auth print-identity-token
```

### Azure

```bash
az login
az account set --subscription <subscription-id>

# Verify
az account show
```

### Kubernetes

```bash
# Local kubeconfig
export KUBECONFIG=~/.kube/config

# EKS
aws eks update-kubeconfig --name <cluster-name> --region <region>

# GKE
gcloud container clusters get-credentials <cluster-name> --region <region>

# AKS
az aks get-credentials --resource-group <rg> --name <cluster>

# Verify
kubectl cluster-info
```

## Tool Output Contract

All CLI wrappers in `tools/clis/` follow this contract:

- **Input**: `<tool> <resource> <action> [--option value]`
- **Output**: JSON to stdout
- **Errors**: JSON `{"error": "message"}` to stderr, exit code 1
- **Credentials**: Read from environment variables, fail fast with install guidance if missing
- **Timeout**: 30 seconds default per command
