# Solutions: Node Not Ready (Scenario 01)

## Root Causes and Solutions

The "Node Not Ready" condition can be caused by several issues. Here are the most common causes and their solutions:

### 1. Kubelet Service Failure

**Symptoms:**
- Kubelet service is stopped or failing
- Node shows NotReady status
- Kubelet logs show service errors or are unavailable

**Solution:**
```bash
# Check kubelet service status
ssh <node-name>
systemctl status kubelet

# Restart kubelet service
sudo systemctl restart kubelet

# If that fails, check logs
sudo journalctl -u kubelet -n 100
```

### 2. Disk Pressure

**Symptoms:**
- Node condition shows "DiskPressure=True"
- Kubelet logs show disk space warnings
- `/var/log` or `/var/lib/kubelet` directories might be full

**Solution:**
```bash
# Check disk usage
ssh <node-name>
df -h

# Clear unnecessary files
sudo du -sch /var/log/* | sort -h
sudo find /var/log -name "*.gz" -delete
sudo find /var/lib/docker/containers -name "*.log" -delete

# Clean docker data
sudo docker system prune -f

# Clean journal logs
sudo journalctl --vacuum-time=1d
```

### 3. Memory Pressure

**Symptoms:**
- Node condition shows "MemoryPressure=True"
- System OOM killer may be activated
- Kubelet or container processes might be killed

**Solution:**
```bash
# Check memory usage
ssh <node-name>
free -h
top

# Check what's consuming memory
ps aux --sort=-%mem | head -10

# Check if swapping is enabled and causing slowness
cat /proc/swaps

# Restart high memory processes or adjust resource limits
```

### 4. Network Connectivity Issues

**Symptoms:**
- Kubelet cannot communicate with API server
- Node LastHeartbeatTime stops updating
- Network timeouts in logs

**Solution:**
```bash
# Check connectivity to API server
ssh <node-name>
curl -k https://<apiserver-ip>:6443/healthz

# Check network interfaces
ip a
ip route

# Check DNS resolution
nslookup kubernetes.default.svc.cluster.local

# Restart networking service
sudo systemctl restart NetworkManager  # or networking/network depending on the distro
```

### 5. Certificate Issues

**Symptoms:**
- Authentication errors in kubelet logs
- Certificate expired or invalid
- TLS handshake failures

**Solution:**
```bash
# Check certificate expiration
ssh <node-name>
sudo openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates

# Regenerate certificates (example for kubeadm clusters)
sudo kubeadm alpha certs renew all

# Manual certificate renewal may be required, depending on your setup
```

### 6. Container Runtime Issues

**Symptoms:**
- Kubelet cannot communicate with container runtime (Docker, containerd)
- CRI errors in kubelet logs
- Containers fail to start

**Solution:**
```bash
# Check container runtime status
ssh <node-name>
sudo systemctl status docker  # or containerd, crio

# Restart container runtime
sudo systemctl restart docker  # or containerd, crio

# Check logs
sudo journalctl -u docker -n 100  # or containerd, crio
```

## Preventive Measures

1. **Implement monitoring and alerting** for node conditions
2. **Set up resource quotas** to prevent resource exhaustion
3. **Configure automatic log rotation** for system and container logs
4. **Schedule certificate renewal** well before expiration
5. **Use node problem detector** to identify node issues early
6. **Implement proper drain procedures** for node maintenance
7. **Create node affinity rules** to ensure critical workloads are distributed

## Additional Troubleshooting Commands

```bash
# Get detailed node information
kubectl describe node <node-name>

# Check events for the node
kubectl get events --field-selector involvedObject.name=<node-name>

# Check pods on the affected node
kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=<node-name>

# Force delete stuck pods (use with caution)
kubectl delete pod <pod-name> --grace-period=0 --force

# Cordon/Drain node for maintenance
kubectl cordon <node-name>
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

## Real-World Considerations

In production environments, nodes might be managed by cloud providers or node auto-provisioning systems. In these cases:

1. Consider replacing the problematic node rather than troubleshooting
2. Use node auto-repair features if available in your cloud platform
3. Ensure your workloads use PodDisruptionBudgets to handle node failures gracefully
4. Design applications for resilience with proper replicas and anti-affinity rules 