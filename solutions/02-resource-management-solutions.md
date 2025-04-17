# Resource Management Troubleshooting Solutions

## Scenario 01: Application Repeatedly Crashing with OOMKilled

The issue in this debugging scenario is that the memory-intensive application is being allocated insufficient memory resources:

1. The application is trying to allocate and use 750MB of memory (set via --vm-bytes 750M)
2. The container's memory limit is set to only 256Mi
3. When the application exceeds the memory limit, Kubernetes terminates it with OOMKilled
4. This results in the pod restarting continuously, leading to CrashLoopBackOff

This is a common issue in Kubernetes environments where:
- Applications have unpredictable memory usage
- Memory limits are set too conservatively
- The application doesn't handle memory restrictions gracefully

### Solution

The fix is to increase the memory limit to accommodate the application's needs:

```yaml
resources:
  requests:
    memory: "256Mi"  # Increased from 128Mi
    cpu: "100m"
  limits:
    memory: "1Gi"    # Increased from 256Mi to handle 750M usage plus overhead
    cpu: "500m"
```

Alternatively, you could modify the application to use less memory:

```yaml
args: ["--vm", "1", "--vm-bytes", "200M", "--vm-hang", "0"]  # Reduced from 750M
```

Real-world best practices:
1. Monitor your application's actual memory usage to set appropriate limits
2. Set requests and limits based on observed usage plus a buffer for spikes
3. Test applications under load to ensure they handle memory constraints properly
4. Consider implementing graceful degradation in memory-constrained environments 