---
title: "Kubernetes Debug"
description: "Debug Kubernetes pod failures, service issues, and cluster problems. Runs preflight checks for kubectl and cluster access, then investigates using hypothesis-driven troubleshooting — gathers evidence from events, logs, and resource state, diagnoses root cause with causal chain analysis, and prescribes fixes."
triggers: ["pod crashing", "pod not starting", "OOMKilled", "CrashLoopBackOff", "ImagePullBackOff", "pod pending", "service unreachable", "debug pod", "k8s debug", "kubectl", "FailedScheduling", "Evicted", "container error", "deployment not rolling out", "pod stuck terminating"]
version: "1.0"
---

# Kubernetes Debug

Autonomous Kubernetes troubleshooting. You investigate pod and service failures using kubectl, gather evidence before asking questions, diagnose root causes with causal chains, and prescribe actionable fixes.

## Preflight

Before starting any investigation, check tool and credential readiness:

```bash
# Run preflight (if available in the plugin)
tools/preflight.sh k8s-debug
```

**Manual checks if preflight is unavailable:**

```bash
# 1. kubectl installed?
which kubectl || echo "INSTALL: brew install kubectl"

# 2. Cluster reachable?
kubectl cluster-info || echo "FIX: export KUBECONFIG=~/.kube/config"
# For EKS: aws eks update-kubeconfig --name <cluster> --region <region>
# For GKE: gcloud container clusters get-credentials <cluster> --region <region>
# For AKS: az aks get-credentials --resource-group <rg> --name <cluster>

# 3. Namespace accessible?
kubectl get namespaces || echo "FIX: Check RBAC permissions"
```

**Do NOT proceed until all checks pass.** Guide the user through fixes for any missing dependency.

---

## Your Thinking Chain

### 1. LISTEN AND INTERPRET SYMPTOMS

What is the user actually experiencing?

- "Pod is crashing" → Which pod? Which namespace? Since when?
- "Can't reach service" → Internal or external? Which endpoint?
- "Deployment stuck" → Rolling update? What's the rollout status?
- "OOMKilled" → Which container? What are the limits?
- "Pods pending" → How long? One pod or all replicas?

Don't interrogate with 20 questions. Instead:
- Extract everything you can from their description
- Discover context automatically with kubectl
- Ask at MOST one targeted clarifying question if you truly cannot proceed

### 2. IDENTIFY FAILING RESOURCES

Start by gathering the current state:

```bash
# Get pods in target namespace (or all namespaces if unknown)
kubectl get pods -n <namespace> -o wide
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded

# Get events sorted by time (most diagnostic data source)
kubectl get events -n <namespace> --sort-by=.lastTimestamp

# Check deployment rollout status
kubectl rollout status deployment/<name> -n <namespace> --timeout=10s

# Quick health overview
kubectl get deployments,statefulsets,daemonsets -n <namespace>
```

### 3. TRIAGE — CLASSIFY THE FAILURE

Based on pod status, route to the right investigation path:

```
Pod Status Decision Tree
════════════════════════

  kubectl get pods → status column
       │
       ├── CrashLoopBackOff ──→ Container starts then crashes
       │                         Go to: STEP 4a (Logs)
       │
       ├── ImagePullBackOff ──→ Can't pull container image
       │   or ErrImagePull       Go to: STEP 4b (Image)
       │
       ├── Pending ───────────→ Can't be scheduled to a node
       │                         Go to: STEP 4c (Scheduling)
       │
       ├── OOMKilled ─────────→ Container exceeded memory limit
       │                         Go to: STEP 4d (Resources)
       │
       ├── Evicted ───────────→ Node under pressure, pod evicted
       │                         Go to: STEP 4e (Node Pressure)
       │
       ├── Terminating ───────→ Pod stuck in termination
       │   (for >5 min)         Go to: STEP 4f (Finalizers)
       │
       ├── Init:Error ────────→ Init container failing
       │   or Init:CrashLoop    Go to: STEP 4g (Init Containers)
       │
       └── Running but ───────→ Pod runs but doesn't serve traffic
           not working           Go to: STEP 4h (Readiness)
```

### 4. INVESTIGATE

#### 4a. CrashLoopBackOff — Container Crash

```bash
# Current logs
kubectl logs <pod> -n <namespace> --tail=100

# Previous container logs (the crash that happened before restart)
kubectl logs <pod> -n <namespace> --previous --tail=100

# If multi-container pod
kubectl logs <pod> -n <namespace> -c <container> --previous --tail=100

# Container exit code
kubectl get pod <pod> -n <namespace> -o jsonpath='{.status.containerStatuses[*].lastState.terminated}'
```

**Common causes:**
- Exit code 1: Application error (check logs for exception/panic/traceback)
- Exit code 137: SIGKILL (OOMKilled or external kill — check `4d`)
- Exit code 139: SIGSEGV (segfault — binary/library issue)
- Exit code 143: SIGTERM (graceful shutdown failed)

**Log patterns to search for:**

```
# Application errors
grep -iE "error|exception|panic|fatal|traceback|failed" /tmp/pod-logs.txt

# Connection failures
grep -iE "connection refused|ECONNREFUSED|timeout|unreachable|no such host" /tmp/pod-logs.txt

# Configuration errors
grep -iE "missing|invalid|not found|undefined|nil|null" /tmp/pod-logs.txt

# Permission errors
grep -iE "permission denied|access denied|forbidden|unauthorized|401|403" /tmp/pod-logs.txt
```

#### 4b. ImagePullBackOff — Image Pull Failure

```bash
# Describe pod to see pull error details
kubectl describe pod <pod> -n <namespace> | grep -A5 "Events:"

# Check image name and tag
kubectl get pod <pod> -n <namespace> -o jsonpath='{.spec.containers[*].image}'

# Check image pull secrets
kubectl get pod <pod> -n <namespace> -o jsonpath='{.spec.imagePullSecrets}'
kubectl get secrets -n <namespace> | grep -i docker
```

**Common causes:**
- Typo in image name or tag
- Tag `:latest` not found (image was never pushed with that tag)
- Private registry without imagePullSecret configured
- Registry authentication expired
- Image was deleted from registry

#### 4c. Pending — Scheduling Failure

```bash
# Events will show WHY it can't schedule
kubectl describe pod <pod> -n <namespace> | grep -A10 "Events:"

# Check node resources
kubectl top nodes
kubectl describe nodes | grep -A5 "Allocated resources"

# Check taints that might block scheduling
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# Check resource requests vs node capacity
kubectl get pod <pod> -n <namespace> -o jsonpath='{.spec.containers[*].resources}'
```

**Common causes:**
- Insufficient cpu/memory on nodes (scale up or reduce requests)
- Node affinity/selector doesn't match any node
- Taints without matching tolerations
- PVC can't be bound (storage class issue, zone mismatch)
- Too many pods (resource quota or node pod limit hit)

#### 4d. OOMKilled — Memory Exceeded

```bash
# Confirm OOM and check limits
kubectl get pod <pod> -n <namespace> -o jsonpath='{.status.containerStatuses[*].lastState.terminated.reason}'
kubectl get pod <pod> -n <namespace> -o jsonpath='{.spec.containers[*].resources}'

# Current memory usage (if pod is running)
kubectl top pod <pod> -n <namespace> --containers

# Check if it's a sudden spike or gradual leak
kubectl get pod <pod> -n <namespace> -o jsonpath='{.status.containerStatuses[*].restartCount}'
```

**Common causes:**
- Memory limit too low for workload (increase limit)
- Memory leak in application (restarts increase over time)
- Sudden traffic spike causing memory surge
- JVM/runtime heap not matching container limits

#### 4e. Evicted — Node Pressure

```bash
# Check node conditions
kubectl describe node <node> | grep -A5 "Conditions:"

# Check for pressure
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="MemoryPressure")].status}{"\t"}{.status.conditions[?(@.type=="DiskPressure")].status}{"\n"}{end}'

# Check eviction events
kubectl get events -A --field-selector=reason=Evicted
```

**Common causes:**
- Node disk pressure (ephemeral storage full — clean up or add emptyDir limits)
- Node memory pressure (too many pods on node)
- Node PID pressure (process limits hit)

#### 4f. Stuck Terminating — Finalizer Block

```bash
# Check finalizers
kubectl get pod <pod> -n <namespace> -o jsonpath='{.metadata.finalizers}'

# Check if delete was issued
kubectl get pod <pod> -n <namespace> -o jsonpath='{.metadata.deletionTimestamp}'

# Force delete (last resort)
# kubectl delete pod <pod> -n <namespace> --grace-period=0 --force
```

**Common causes:**
- Finalizer waiting for external resource cleanup
- Preemption or disruption budget blocking
- Volume unmount stuck

#### 4g. Init Container Failure

```bash
# Check init container status
kubectl get pod <pod> -n <namespace> -o jsonpath='{.status.initContainerStatuses}'

# Logs of failing init container
kubectl logs <pod> -n <namespace> -c <init-container-name>

# List init containers
kubectl get pod <pod> -n <namespace> -o jsonpath='{.spec.initContainers[*].name}'
```

**Common causes:**
- Init container waiting for a dependency (database, service) that isn't ready
- ConfigMap or Secret not found
- Permission issue in init script

#### 4h. Running But Not Serving — Readiness Probe

```bash
# Check probe configuration
kubectl get pod <pod> -n <namespace> -o jsonpath='{.spec.containers[*].readinessProbe}'
kubectl get pod <pod> -n <namespace> -o jsonpath='{.spec.containers[*].livenessProbe}'

# Check endpoints (are pods registered?)
kubectl get endpoints <service> -n <namespace>

# Test connectivity from inside cluster
kubectl run debug-net --image=busybox --rm -it --restart=Never -- wget -qO- http://<service>.<namespace>:port/healthz

# Check service selector matches pod labels
kubectl get svc <service> -n <namespace> -o jsonpath='{.spec.selector}'
kubectl get pod <pod> -n <namespace> -o jsonpath='{.metadata.labels}'
```

**Common causes:**
- Readiness probe path wrong or app not listening on expected port
- Service selector doesn't match pod labels
- NetworkPolicy blocking traffic
- App started but health endpoint returns error

---

### 5. FORM HYPOTHESES

Based on evidence gathered, present ranked theories:

```
Hypothesis Ranking
══════════════════

  #1 (most likely)  ┌────────────────────────────────────┐
                    │ [Hypothesis based on evidence]     │
                    │ Evidence: [what you found]         │
                    └────────────────────────────────────┘

  #2                ┌────────────────────────────────────┐
                    │ [Alternative explanation]          │
                    │ Evidence: [what supports this]     │
                    └────────────────────────────────────┘

  Investigating #1 first (fastest to confirm/rule out)...
```

Rank by:
- **Probability**: Most common explanations first
- **Impact**: Check high-impact causes even if less likely
- **Testability**: Start with what's fastest to confirm or rule out

### 6. DIAGNOSE THE ROOT CAUSE

Connect evidence to a root cause. Present the causal chain:

```
Root Cause Analysis
═══════════════════

  Root cause:
  ┌─────────────────────────────────────────────────────┐
  │ [Root cause in plain English]                       │
  └──────────────────────┬──────────────────────────────┘
                         │ caused
                         ▼
  ┌─────────────────────────────────────────────────────┐
  │ [Secondary effect/error]                            │
  └──────────────────────┬──────────────────────────────┘
                         │ caused
                         ▼
  ┌─────────────────────────────────────────────────────┐
  │ [Visible symptom to user]                           │
  └─────────────────────────────────────────────────────┘

  Confidence: [HIGH/MEDIUM/LOW] — [explain reasoning]
```

Provide:
- **Root cause** in plain English anyone can understand
- **Evidence** — exact error messages, event timestamps, resource values
- **Confidence level** with reasoning
- **Causal chain** as ASCII diagram

### 7. PRESCRIBE AND FIX

Offer actionable resolution:

```bash
# Example fixes by failure type:

# OOMKilled → increase memory limit
kubectl patch deployment <name> -n <namespace> -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container>","resources":{"limits":{"memory":"512Mi"}}}]}}}}'

# CrashLoopBackOff due to config → fix configmap
kubectl edit configmap <name> -n <namespace>

# ImagePullBackOff → create/fix pull secret
kubectl create secret docker-registry regcred --docker-server=<registry> --docker-username=<user> --docker-password=<pass> -n <namespace>

# Pending due to resources → scale nodes or reduce requests
kubectl patch deployment <name> -n <namespace> -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container>","resources":{"requests":{"cpu":"100m","memory":"128Mi"}}}]}}}}'

# Stuck terminating → remove finalizer
kubectl patch pod <pod> -n <namespace> -p '{"metadata":{"finalizers":null}}'
```

**Before applying any fix:**
- Explain what the fix does and why, in plain English
- If the fix carries risk, explain trade-offs (e.g. "This will restart the pod")
- If there are multiple options, present them with trade-offs
- Ask for confirmation on destructive operations

### 8. VERIFY

After fix is applied, confirm it worked:

```bash
# Check pod status
kubectl get pods -n <namespace> -l app=<label>

# Watch rollout
kubectl rollout status deployment/<name> -n <namespace> --timeout=120s

# Verify endpoints are registered
kubectl get endpoints <service> -n <namespace>

# Check events for new issues
kubectl get events -n <namespace> --sort-by=.lastTimestamp | tail -10

# Quick health check
kubectl top pod -n <namespace> -l app=<label>
```

Present before/after comparison:

```
Fix Verification
════════════════

  BEFORE                          AFTER
  ┌──────────────────────┐       ┌──────────────────────┐
  │ pod: CrashLoopBackOff│  ──→  │ pod: Running (2m)    │
  │ restarts: 47         │       │ restarts: 0          │
  │ endpoints: 0/3       │       │ endpoints: 3/3       │
  └──────────────────────┘       └──────────────────────┘

  ✓ Fix confirmed. Pod stable for 2 minutes with 0 restarts.
```

---

## Error Classification Reference

| Category | Patterns | Meaning |
|----------|----------|---------|
| **Scheduling** | `CrashLoopBackOff`, `OOMKilled`, `ImagePullBackOff`, `Pending`, `FailedScheduling` | Pod lifecycle failures |
| **State** | `state lock`, `ConflictException`, `already exists`, `object has been modified` | Resource state conflicts |
| **Permission** | `AccessDenied`, `Forbidden`, `unauthorized`, `403`, `401` | RBAC/auth failures |
| **Network** | `connection refused`, `timeout`, `no such host`, `unreachable` | Connectivity issues |
| **Configuration** | `missing`, `invalid`, `not found`, `undefined`, `nil` | Bad config values |

## Diagnostic Instincts

- **Correlation is not causation**: X happening before Y doesn't mean X caused Y — look for mechanism
- **Cascading failures deceive**: The first error is often not the root cause — trace backwards
- **Recent changes are prime suspects**: Always correlate timing of symptoms with recent deployments
- **Environment differences explain a lot**: "Works in staging, broken in prod" — systematically diff the two
- **The obvious answer is often right**: Don't overthink when a typo or missing env var explains everything
- **Check events first**: `kubectl get events` is the single most diagnostic data source in Kubernetes

## Communication Standards

- **ALWAYS use ASCII diagrams** for hypothesis ranking, causal chains, and before/after comparisons
- **Never dump raw logs** — synthesize into insight
- **Never report error codes without explaining what they mean**
- **Never guess without evidence** — say "I need to investigate further"
- **Never leave the user without a clear next step**
- **Be concise for simple errors, detailed for complex cascading failures**
