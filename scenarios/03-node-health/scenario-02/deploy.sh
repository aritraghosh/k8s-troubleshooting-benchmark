#!/bin/bash

# Define colors for better readability
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print separator line
print_separator() {
  echo -e "${YELLOW}---------------------------------------------------------------${NC}"
}

print_separator
echo -e "${GREEN}Deploying Memory Pressure Scenario${NC}"
print_separator

# Create namespace
echo -e "\nCreating namespace debug-node-02..."
kubectl create namespace debug-node-02

# Get the names of nodes in the cluster
echo -e "\nGetting cluster node information..."
NODES=($(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'))
NODE_COUNT=${#NODES[@]}

if [ "$NODE_COUNT" -lt 2 ]; then
  echo -e "${RED}This scenario requires at least 2 nodes in your cluster.${NC}"
  echo -e "${RED}You have only $NODE_COUNT node(s). Cannot continue.${NC}"
  echo -e "\nCleaning up..."
  kubectl delete namespace debug-node-02
  exit 1
fi

# Select a node to mark as not ready (not the first node, which might be control plane)
TARGET_NODE=${NODES[1]}
if [ "$NODE_COUNT" -gt 2 ]; then
  # If we have more than 2 nodes, randomly select one that's not the first
  RANDOM_INDEX=$(( RANDOM % (NODE_COUNT-1) + 1 ))
  TARGET_NODE=${NODES[$RANDOM_INDEX]}
fi

echo -e "\n${YELLOW}Selected node for simulation: ${TARGET_NODE}${NC}"

# Deploy regular workloads first across all nodes
echo -e "\nDeploying regular workloads across all nodes..."
kubectl create deployment normal-workload -n debug-node-02 --image=nginx --replicas=3

# Expose the normal workload
echo -e "\nExposing normal workload through a service..."
kubectl expose deployment normal-workload -n debug-node-02 --port=80 --target-port=80

# Set up monitoring pod
echo -e "\nDeploying monitoring pods to observe memory usage..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: memory-monitor
  namespace: debug-node-02
spec:
  selector:
    matchLabels:
      app: memory-monitor
  template:
    metadata:
      labels:
        app: memory-monitor
    spec:
      containers:
      - name: monitor
        image: busybox
        command: ["/bin/sh", "-c"]
        args:
        - |
          while true; do
            echo "==== Memory Status at \$(date) ===="
            free -m
            echo "==== Top Memory Processes ===="
            ps aux --sort=-%mem | head -5
            
            # Create simulated kubelet memory pressure logs
            if [ -d /var/log/kubelet-simulation ]; then
              echo "[\$(date)] kubelet[12345]: Node memory pressure detected, current usage: 95%" >> /var/log/kubelet-simulation/kubelet.log
              echo "[\$(date)] kernel: Memory cgroup out of memory: Killed process 30123" >> /var/log/kubelet-simulation/kernel.log
            fi
            
            sleep 10
          done
        volumeMounts:
        - name: simulation-logs
          mountPath: /var/log/kubelet-simulation
      volumes:
      - name: simulation-logs
        emptyDir: {}
      tolerations:
      - key: "node.kubernetes.io/memory-pressure"
        operator: "Exists"
        effect: "NoSchedule"
EOF

# Deploy victim pods that will be evicted when memory pressure occurs
echo -e "\nDeploying victim pods to the target node..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: victim-pods
  namespace: debug-node-02
spec:
  replicas: 5
  selector:
    matchLabels:
      app: victim
  template:
    metadata:
      labels:
        app: victim
    spec:
      nodeSelector:
        kubernetes.io/hostname: ${TARGET_NODE}
      containers:
      - name: web-app
        image: nginx
        resources:
          requests:
            memory: "50Mi"
          limits:
            memory: "100Mi"
EOF

# Wait for victim pods to be scheduled
echo -e "\nWaiting for victim pods to be scheduled on the target node..."
sleep 10

# Now deploy the memory-hungry DaemonSet only to the target node
echo -e "\n${YELLOW}Deploying memory-hungry workload to the target node...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: memory-hog
  namespace: debug-node-02
spec:
  selector:
    matchLabels:
      app: memory-hog
  template:
    metadata:
      labels:
        app: memory-hog
    spec:
      nodeSelector:
        kubernetes.io/hostname: ${TARGET_NODE}
      containers:
      - name: memory-stress
        image: polinux/stress
        command: ["/bin/sh", "-c"]
        args:
        - |
          # Get host memory information
          if [ -f /proc/meminfo ]; then
            NODE_MEMORY_KB=\$(grep MemTotal /proc/meminfo | awk '{print \$2}')
          else
            # Assume 8GB if we can't detect
            NODE_MEMORY_KB=8388608
          fi
          
          # Target 80% of node memory
          TARGET_MEMORY=\$((NODE_MEMORY_KB * 80 / 100))
          echo "Node has \${NODE_MEMORY_KB}KB memory, consuming \${TARGET_MEMORY}KB"
          
          # Gradually increase memory usage
          for i in \$(seq 1 5); do
            STEP=\$((TARGET_MEMORY * i / 5))
            echo "Step \$i: Consuming \${STEP}KB memory..."
            stress-ng --vm 1 --vm-bytes \${STEP}K --vm-hang 0 --timeout 30s
            sleep 5
          done
          
          # Hold at max consumption
          echo "Holding at maximum consumption..."
          stress-ng --vm 1 --vm-bytes \${TARGET_MEMORY}K --vm-hang 0 --verbose
        resources:
          requests:
            memory: "100Mi"
          limits:
            memory: "16Gi"  # High limit to avoid container being OOM killed
        securityContext:
          privileged: true  # Needed to affect node-level resources
        volumeMounts:
        - name: host-proc
          mountPath: /host/proc
          readOnly: true
      volumes:
      - name: host-proc
        hostPath:
          path: /proc
      tolerations:
      - key: "node.kubernetes.io/memory-pressure"
        operator: "Exists"
        effect: "NoSchedule"
EOF

# Apply the control tooling via a ConfigMap
echo -e "\nCreating control tools for the scenario..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: memory-pressure-controller
  namespace: debug-node-02
data:
  apply-pressure.sh: |
    #!/bin/sh
    echo "Simulating memory pressure effects on node ${TARGET_NODE}..."
    
    # Cordon the node to prevent new pods
    kubectl cordon ${TARGET_NODE}
    
    # Apply memory pressure condition
    kubectl patch node ${TARGET_NODE} -p '{"status":{"conditions":[{"type":"MemoryPressure","status":"True","reason":"KubeletHasInsufficientMemory","message":"kubelet has insufficient memory available"}]}}'
    
    # Apply memory pressure taint
    kubectl taint nodes ${TARGET_NODE} node.kubernetes.io/memory-pressure=true:NoSchedule --overwrite
    
    # Update the Ready condition to False due to memory pressure
    kubectl patch node ${TARGET_NODE} -p '{"status":{"conditions":[{"type":"Ready","status":"False","reason":"KubeletNotReady","message":"Memory pressure detected"}]}}'
    
    # Simulate some pod evictions
    POD_LIST=\$(kubectl get pods -n debug-node-02 -l app=victim -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | head -3)
    for pod in \$POD_LIST; do
      echo "Evicting pod \$pod..."
      kubectl delete pod \$pod -n debug-node-02
    done
    
    echo "Memory pressure simulation active on node ${TARGET_NODE}"
    
  simulate-oom-events.sh: |
    #!/bin/sh
    echo "Simulating OOM events in node logs..."
    
    # These would typically appear in journalctl or kubectl logs
    cat <<EVENTS
[$(date +"%Y-%m-%d %H:%M:%S")] kernel: [42156.789012] Memory cgroup out of memory: Killed process 2461 (nginx) total-vm:1298788kB, anon-rss:1092548kB, file-rss:0kB, shmem-rss:0kB, UID:0
[$(date +"%Y-%m-%d %H:%M:%S")] kernel: [42157.123456] oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/kubepods,mems_allowed=0,oom_memcg=/kubepods/burstable/pod12345,task_memcg=/kubepods/burstable/pod12345,task=nginx,pid=2461,uid=0
[$(date +"%Y-%m-%d %H:%M:%S")] kernel: [42157.456789] Memory cgroup stats: cache:0kB rss:1092548kB rss_huge:0kB mapped_file:0kB swap:0kB inactive_anon:0kB active_anon:1092548kB inactive_file:0kB active_file:0kB unevictable:0kB
[$(date +"%Y-%m-%d %H:%M:%S")] kubelet: E0725 10:42:15.123456   12345 eviction_manager.go:255] Eviction manager: pods pod12345 pod23456 pod34567 evicted, waiting for pod to be cleaned up
EVENTS
    
    echo "OOM events simulation complete"
EOF

# Deploy control pods
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: memory-controller
  namespace: debug-node-02
spec:
  containers:
  - name: controller
    image: bitnami/kubectl
    command: ["/bin/sh", "-c"]
    args:
    - |
      cp /scripts/* /tmp/
      chmod +x /tmp/*.sh
      
      # Wait a bit for the memory-hog to start consuming
      echo "Waiting for memory hog to start consuming resources..."
      sleep 60
      
      # Apply memory pressure conditions
      /tmp/apply-pressure.sh
      
      # Simulate OOM events
      /tmp/simulate-oom-events.sh
      
      echo "Memory pressure scenario activated. Press Ctrl+C to exit"
      tail -f /dev/null
    volumeMounts:
    - name: controller-scripts
      mountPath: /scripts
  volumes:
  - name: controller-scripts
    configMap:
      name: memory-pressure-controller
      defaultMode: 0777
EOF

print_separator
echo -e "${GREEN}Memory Pressure Scenario Deployed!${NC}"
print_separator
echo -e "\n${YELLOW}Scenario Setup:${NC}"
echo -e "* Node ${TARGET_NODE} will experience memory pressure"
echo -e "* A memory-hungry pod has been deployed to this node"
echo -e "* The node should eventually show MemoryPressure=True and transition to NotReady"
echo -e "* Victim pods on the node will be evicted or show OOMKilled status"
echo -e "\n${YELLOW}Diagnosis Steps:${NC}"
echo -e "1. Check node status: ${GREEN}kubectl get nodes${NC}"
echo -e "2. Check node conditions: ${GREEN}kubectl describe node $TARGET_NODE${NC}"
echo -e "3. Check memory metrics: ${GREEN}kubectl logs -n debug-node-02 -l app=memory-monitor${NC}"
echo -e "4. Check pod status: ${GREEN}kubectl get pods -n debug-node-02 -o wide${NC}"
echo -e "5. Check events: ${GREEN}kubectl get events -n debug-node-02${NC}"
echo -e "\n${YELLOW}Expected Observations:${NC}"
echo -e "* Node $TARGET_NODE will show MemoryPressure=True"
echo -e "* Node may transition to NotReady state"
echo -e "* Pods will be evicted from the node"
echo -e "* Memory-related OOM events will be visible in node logs"
echo -e "\n${YELLOW}Your task:${NC} Diagnose the issue, determine the root cause, and resolve it."
echo -e "When you're ready to restore the node, run the cleanup script: ${GREEN}./cleanup.sh${NC}"
print_separator 