# Solutions: Node Memory Pressure (Scenario 02)

## Root Cause

The root cause of the issue is excessive memory consumption on the node, leading to memory pressure and potentially a NotReady condition. This causes pod evictions, OOM kills, and scheduling failures.

In this scenario, a memory-hungry workload (the `memory-hog` DaemonSet) is intentionally consuming large amounts of memory on the target node, pushing it into a Memory Pressure state.

## How to Verify the Issue

1. Check node conditions to confirm memory pressure:
```bash
kubectl get nodes
kubectl describe node <affected-node-name>
```
The output will show `MemoryPressure=True` and potentially `Ready=False`.

2. Identify pods consuming the most memory:
```bash
kubectl top pods --all-namespaces --sort-by=memory
```
Look for pods with unusually high memory usage, especially those running on the affected node.

3. Check memory statistics on the node:
```bash
# If you have access to the node:
free -m
top
```

4. Look for OOM kill events:
```bash
# If you have access to the node:
dmesg | grep -i oom
journalctl -u kubelet | grep -i memory
```

5. Check for pod evictions in events:
```bash
kubectl get events --sort-by=.metadata.creationTimestamp
```
Look for events indicating pods were evicted due to memory pressure.

## Solutions

### 1. Immediate Relief: Remove Memory-Hungry Workloads

The fastest way to relieve memory pressure is to identify and remove the workloads consuming excessive memory:

```bash
# Identify the problematic pods or DaemonSets
kubectl get pods --all-namespaces -o wide | grep <node-name>
kubectl top pod --all-namespaces --sort-by=memory

# Remove the memory-hogging workload
kubectl delete pod <pod-name> -n <namespace>
# Or for a DaemonSet:
kubectl delete daemonset memory-hog -n debug-node-02
```

### 2. Set Appropriate Resource Limits

To prevent future issues, ensure all deployments have appropriate memory limits:

```yaml
resources:
  requests:
    memory: "128Mi"  # Minimum memory needed
  limits:
    memory: "256Mi"  # Maximum memory allowed
```

Apply these changes to the problematic deployments:
```bash
kubectl set resources deployment <deployment-name> -n <namespace> --limits=memory=256Mi --requests=memory=128Mi
```

### 3. Isolate Critical Workloads

Use node affinity and taints/tolerations to ensure critical workloads don't run on nodes with limited resources:

```yaml
# Add to pod spec
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: node-type
          operator: In
          values:
          - high-memory
```

### 4. Increase Node Resources

If this is a recurring issue, consider:
- Scaling up nodes with more memory
- Adding more nodes to the cluster
- Using node autoscaling for demand spikes

### 5. Implement Memory-Based Pod Autoscaling

For workloads with variable memory needs, implement Horizontal Pod Autoscaler based on memory metrics:

```bash
kubectl autoscale deployment <deployment-name> --min=1 --max=10 --cpu-percent=80
```

### 6. Configure Proper Eviction Thresholds

Adjust kubelet eviction thresholds if the default values aren't appropriate for your workloads:

```bash
--eviction-hard=memory.available<10%
--eviction-soft=memory.available<20%
--eviction-soft-grace-period=memory.available=2m
```

## Specific Solution for This Scenario

In this scenario, the culprit is the `memory-hog` DaemonSet. To resolve:

1. Delete the memory-hogging DaemonSet:
```bash
kubectl delete daemonset memory-hog -n debug-node-02
```

2. Remove memory pressure condition and taint:
```bash
kubectl patch node <node-name> -p '{"status":{"conditions":[{"type":"MemoryPressure","status":"False"}]}}'
kubectl taint nodes <node-name> node.kubernetes.io/memory-pressure-
```

3. If needed, restore the node's Ready status:
```bash
kubectl patch node <node-name> -p '{"status":{"conditions":[{"type":"Ready","status":"True"}]}}'
```

4. Uncordon the node to allow scheduling:
```bash
kubectl uncordon <node-name>
```

## Preventive Measures

1. **Implement resource monitoring** to detect high memory usage before it causes problems
2. **Set appropriate resource requests and limits** for all workloads
3. **Use resource quotas** at the namespace level
4. **Configure LimitRanges** to enforce defaults for pods without specified limits
5. **Implement cluster autoscaling** to handle resource demand spikes
6. **Create PodDisruptionBudgets** for critical applications to maintain availability during evictions
7. **Optimize application memory usage** through profiling and tuning
8. **Set up alerting** for node pressure conditions

## Additional Troubleshooting Commands

```bash
# Get node metrics
kubectl top nodes

# Check pod resource usage
kubectl top pods --all-namespaces --sort-by=memory

# Check events related to memory
kubectl get events --field-selector involvedObject.name=<pod-name>

# View complete resource usage of a pod
kubectl describe pod <pod-name> -n <namespace>

# Check what kubelet sees for memory pressure
kubectl get --raw /api/v1/nodes/<node-name>/proxy/metrics/resource

# List pods on the affected node
kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=<node-name>
``` 