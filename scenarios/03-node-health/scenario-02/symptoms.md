# Scenario 02: Node Memory Pressure

## Symptoms

* One node in the cluster shows "MemoryPressure=True" condition
* The same node may eventually transition to "NotReady" state
* Pods on the affected node are being evicted or terminated
* Some pods show "OOMKilled" status
* New pods targeting this node remain in "Pending" state
* Kubelet logs show memory-related warnings and errors
* System metrics show high memory utilization on the affected node

## Expected Behavior

Nodes should maintain sufficient memory resources for both the kubelet and container workloads. Memory pressure should be avoided through proper resource allocation and limits.

## Observed Behaviors

* Running `kubectl get nodes` shows one node with status "MemoryPressure=True" or "NotReady"
* Running `kubectl describe node <node-name>` shows memory pressure condition
* Pod evictions are occurring automatically as the node tries to reclaim memory
* The `free -m` command on the node shows little to no available memory
* OOM killer is terminating pods or processes to maintain node stability
* Memory-intensive processes are visible in the top memory consumers list
* Kubernetes events show "evicted due to memory pressure" messages

## Key Debugging Steps

1. Check node conditions and status (`kubectl get nodes`, `kubectl describe node <node-name>`)
2. Identify memory-hungry pods (`kubectl top pod --all-namespaces`)
3. Examine memory usage statistics on the node (`free -m`, `top`)
4. Review recent OOM kill events (`dmesg | grep -i oom`)
5. Check kubelet logs for memory pressure warnings (`journalctl -u kubelet | grep memory`)
6. Analyze resource requests and limits of pods on the node
7. Identify potential memory leaks in applications
8. Check for system daemons or processes consuming excessive memory 