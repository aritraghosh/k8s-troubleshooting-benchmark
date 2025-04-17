# Node Health Troubleshooting Solutions

## Scenario 01: Node Not Ready

In this debugging scenario, a node in the Kubernetes cluster enters the NotReady state, causing workload disruption and pod evictions.

### Root Causes

The "NotReady" condition can be triggered by several issues:

1. **Kubelet Service Issues**
   - Kubelet service stopped or crashed
   - Kubelet unable to communicate with the API server
   - Configuration errors in kubelet settings

2. **Resource Exhaustion**
   - Disk pressure (node running out of disk space)
   - Memory pressure (insufficient memory for system processes)
   - PID limits exceeded

3. **Network Problems**
   - Network connectivity issues between node and control plane
   - DNS resolution failures
   - CNI plugin errors or network interface issues

4. **Certificate Problems**
   - Expired kubelet client or server certificates
   - Incorrect certificate permissions
   - Certificate authentication failures

5. **Container Runtime Issues**
   - Docker/containerd daemon failures
   - CRI compatibility problems
   - Container runtime resource constraints

### Diagnostic Process

The effective troubleshooting of NotReady nodes follows this pattern:

1. **Observe the symptoms:**
   ```bash
   kubectl get nodes                               # Identify NotReady nodes
   kubectl describe node <node-name>               # Check node conditions and events
   kubectl get pods --all-namespaces -o wide       # Check impact on workloads
   kubectl get events --field-selector involvedObject.name=<node-name>  # Check node events
   ```

2. **Check kubelet status** (requires SSH access to the node):
   ```bash
   systemctl status kubelet                        # Check if kubelet is running
   journalctl -u kubelet -n 100                    # Check kubelet logs
   ```

3. **Check for resource constraints**:
   ```bash
   df -h                                           # Check disk space
   free -h                                         # Check memory usage
   top                                             # Check CPU and memory by process
   ```

4. **Verify network connectivity**:
   ```bash
   ping <api-server-ip>                            # Basic connectivity
   curl -k https://<apiserver-ip>:6443/healthz     # API server health
   ```

5. **Check certificate validity**:
   ```bash
   openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates
   ```

6. **Examine container runtime**:
   ```bash
   systemctl status docker                         # or containerd/crio
   docker info                                     # Check for warnings or errors
   ```

### Solutions

The solution depends on the root cause:

#### 1. For kubelet service issues:
```bash
# Restart kubelet
sudo systemctl restart kubelet

# If configuration is incorrect, fix kubelet config file
sudo vi /var/lib/kubelet/config.yaml

# Check for error logs
sudo journalctl -u kubelet -f
```

#### 2. For disk pressure:
```bash
# Clean up old logs and containers
sudo find /var/log -name "*.gz" -delete
sudo docker system prune -f
sudo journalctl --vacuum-time=1d

# Add more disk space if available
```

#### 3. For memory pressure:
```bash
# Identify and restart memory-hogging processes
ps aux --sort=-%mem | head -10
kill -9 <PID>

# Consider adding swap (not recommended for production) or more RAM
```

#### 4. For network issues:
```bash
# Restart networking service
sudo systemctl restart NetworkManager  # or equivalent

# Check and fix network interface
ip addr
ip route

# Restart CNI if applicable
sudo systemctl restart calico-node  # example for Calico
```

#### 5. For certificate issues:
```bash
# For kubeadm clusters, renew certificates
sudo kubeadm alpha certs renew all

# Manually renew certificates for other setups
# Ensure proper permissions
sudo chmod 600 /var/lib/kubelet/pki/*
```

#### 6. For container runtime issues:
```bash
# Restart container runtime
sudo systemctl restart docker  # or containerd, crio

# Check logs for errors
sudo journalctl -u docker -n 100
```

### Best Practices to Prevent Node NotReady Issues

1. **Implement monitoring and alerting** for early detection
2. **Configure automatic log rotation** to prevent disk pressure
3. **Use resource quotas and limits** to prevent resource exhaustion
4. **Implement certificate auto-renewal** before expiration
5. **Schedule regular node maintenance** with proper draining procedures
6. **Use node problem detector** for automatic issue detection
7. **Design applications for resilience** with proper pod distribution

### Simulated Scenario Notes

In the benchmark scenario, we simulate a NotReady node by:

1. Cordoning the node to prevent new pod scheduling
2. Applying taints that mimic the NotReady condition
3. Patching the node status to show NotReady

To resolve the simulated issue, the cleanup script:

1. Removes the NotReady taints
2. Patches the node status back to Ready
3. Uncordons the node
4. Removes all deployed testing resources

This simulation provides a safe way to practice troubleshooting NotReady nodes without actually causing node failures in your cluster.

---

## Scenario 02: Node Memory Pressure

In this debugging scenario, a node in the Kubernetes cluster experiences memory pressure, leading to pod evictions, OOM kills, and potentially a NotReady state.

### Root Cause

The root cause is excessive memory consumption on the node, either by:

1. **Memory-hungry container workloads**
   - Pods with high memory consumption
   - Pods with memory leaks
   - Pods without appropriate memory limits

2. **System-level processes**
   - Node system daemons using too much memory
   - Kubelet itself consuming excessive memory
   - Kernel or operating system memory leaks

3. **Resource allocation issues**
   - Over-committed node resources
   - Insufficient memory for the workload profile
   - Improperly configured eviction thresholds

### Diagnostic Process

Memory pressure issues can be identified through:

1. **Check node conditions:**
   ```bash
   kubectl get nodes
   kubectl describe node <node-name>
   ```
   Look for `MemoryPressure=True` condition and memory-related taints.

2. **Identify memory-hungry pods:**
   ```bash
   kubectl top pods --all-namespaces --sort-by=memory
   kubectl get pods --all-namespaces -o wide | grep <node-name>
   ```

3. **Examine system memory:**
   ```bash
   # If you have node access:
   free -m
   top
   ps aux --sort=-%mem
   ```

4. **Check for OOM events:**
   ```bash
   dmesg | grep -i oom
   journalctl -u kubelet | grep -i "memory pressure"
   ```

5. **Review Kubernetes events:**
   ```bash
   kubectl get events --sort-by=.metadata.creationTimestamp
   ```
   Look for eviction events related to memory pressure.

### Solutions

#### 1. Immediate Memory Relief

The immediate goal is to reduce memory pressure:

```bash
# Identify and remove memory-hungry pods
kubectl top pods --all-namespaces --sort-by=memory
kubectl delete pod <memory-hogging-pod> -n <namespace>

# For DaemonSets or Deployments:
kubectl delete daemonset <name> -n <namespace>
kubectl scale deployment <name> --replicas=0 -n <namespace>
```

#### 2. Configure Resource Limits

Implement appropriate memory limits for all workloads:

```yaml
resources:
  requests:
    memory: "128Mi"  # Minimum needed memory
  limits:
    memory: "256Mi"  # Maximum allowed memory
```

Apply limits to existing deployments:

```bash
kubectl set resources deployment <name> -n <namespace> --limits=memory=256Mi --requests=memory=128Mi
```

#### 3. Node-Level Remediation

If system-level issues are causing memory pressure:

```bash
# Restart kubelet service
sudo systemctl restart kubelet

# Identify and restart memory-intensive system processes
ps aux --sort=-%mem | head -10
sudo systemctl restart <service-name>

# Add swap space (not recommended for production K8s nodes, but can help in emergencies)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

#### 4. Long-Term Strategies

- **Implement resource quotas** at namespace level
- **Use LimitRanges** to enforce default limits
- **Optimize application memory usage**
- **Add more memory capacity** to nodes
- **Implement cluster autoscaling**
- **Set up monitoring and alerting** for memory metrics

### Preventive Measures

1. **Properly size pods and nodes** based on actual workload requirements
2. **Implement memory monitoring** with alerts before pressure occurs
3. **Use resource quotas** at namespace level
4. **Configure appropriate kubelet eviction thresholds**
5. **Test workloads under load** to identify memory consumption patterns
6. **Schedule regular garbage collection** for languages with managed memory
7. **Use container memory limits** as a safety mechanism
8. **Create node affinity rules** to distribute memory-intensive workloads

### Simulated Scenario Notes

In the benchmark scenario, memory pressure is simulated by:

1. Deploying a memory-intensive DaemonSet to the target node
2. Gradually increasing memory consumption to avoid sudden node failures
3. Applying memory pressure conditions and taints
4. Simulating pod evictions and OOM events

The cleanup script addresses this by:

1. Removing the memory-intensive workloads
2. Clearing memory pressure conditions and taints
3. Restoring the node to a normal Ready state
4. Removing all test resources

This realistic simulation allows safe practice of memory pressure troubleshooting without risking actual cluster stability. 