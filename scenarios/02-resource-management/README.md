# Resource Management Troubleshooting Scenarios

This directory contains scenarios related to Kubernetes resource management issues, including:

- Resource limits and requests configuration
- Pod scheduling and resource allocation
- Node resource pressure and evictions
- Horizontal Pod Autoscaler issues
- Resource quotas and limit ranges

## Scenarios

### Scenario 01: Application Repeatedly Crashing with OOMKilled

A memory-intensive application keeps crashing due to resource constraints. The pod enters CrashLoopBackOff state and Kubernetes events show OOMKilled as the termination reason.

**Skills tested:**
- Diagnosing container resource usage
- Understanding Kubernetes resource limits and requests
- Analyzing pod crash patterns
- Configuring appropriate memory limits

**Difficulty:** Beginner

**To deploy this scenario:**
```bash
cd scenario-01
./deploy.sh
```

**To clean up:**
```bash
./cleanup.sh
``` 