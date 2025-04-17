# Scenario 01: Node Not Ready

## Symptoms

* One node in the cluster shows status "NotReady"
* Pods scheduled on the affected node are stuck in "Terminating" or "Unknown" state
* New pods scheduled to this node remain in "Pending" state
* Cluster-wide workload disruption as pods are evicted from the problematic node
* Kubelet logs on the affected node show connection timeouts or errors

## Expected Behavior

All nodes in the cluster should be in "Ready" state, with the kubelet service running correctly on each node and properly reporting status to the control plane.

## Observed Behaviors

* Running `kubectl get nodes` shows one node with status "NotReady"
* Node conditions show "False" for Ready condition
* Pod evictions are triggered automatically after the node grace period
* The node's LastHeartbeatTime stops updating
* Communication between the kubelet and kube-apiserver is broken
* Node pressure may be observed (disk pressure, memory pressure, or PID pressure)
* System services on the node may show failures

## Key Debugging Steps

1. Check node status and conditions (`kubectl get nodes`, `kubectl describe node <node-name>`)
2. Examine kubelet logs on the affected node (if accessible)
3. Verify kubelet service status on the node
4. Check node resource utilization (disk space, memory, CPU)
5. Inspect network connectivity between the node and control plane
6. Review system logs for kernel or hardware issues
7. Check certificate expiration for kubelet 