# Eval Report: k8s-debug

- **Date:** 2026-04-15 06:51 UTC
- **Model:** sonnet
- **Skill version:** 2.0

| Eval | Scenario | Result | Assertions |
| ---- | -------- | ------ | ---------- |
| #1 | My pod keeps restarting in production. It was work... | FAIL | 5/7 |
| #2 | Pods are in ImagePullBackOff after a deploy.... | FAIL | 5/6 |
| #3 | Pod shows exit code 137 and keeps crashing.... | PASS | 7/7 |
| #4 | our app is OOMKilled every few hours. it runs fine... | PASS | 7/7 |
| #5 | Service is returning 503s but all pods show Runnin... | PASS | 6/6 |
| #6 | Pods are pending. Nodes seem fine.... | PASS | 6/6 |
| #7 | Init container is failing. Pod shows Init:0/2. I c... | PASS | 5/5 |
| #8 | I think the pod is crashing because of a config is... | PASS | 6/6 |
| #9 | Multiple pods across different deployments are fai... | FAIL | 6/7 |
| #10 | Pod was evicted after we did node maintenance. The... | FAIL | 5/6 |
| #11 | Can you review my Terraform plan for the new VPC?... | PASS | 4/4 |
| #12 | kubectl is not working on my machine.... | FAIL | 0/4 |

**Result: 5 FAILED, 7 passed**
