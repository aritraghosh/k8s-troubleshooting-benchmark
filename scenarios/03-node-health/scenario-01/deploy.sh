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
echo -e "${GREEN}Deploying Node Not Ready Scenario${NC}"
print_separator

# Create namespace
echo -e "\nCreating namespace debug-node-01..."
kubectl create namespace debug-node-01

# Deploy some workloads to make the scenario more realistic
echo -e "\nDeploying test application across nodes..."
kubectl create deployment test-app -n debug-node-01 --image=nginx --replicas=5

# Expose the application through a service
echo -e "\nExposing test application through a service..."
kubectl expose deployment test-app -n debug-node-01 --port=80 --target-port=80

# Get the names of nodes in the cluster
echo -e "\nGetting cluster node information..."
NODES=($(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'))
NODE_COUNT=${#NODES[@]}

if [ "$NODE_COUNT" -lt 2 ]; then
  echo -e "${RED}This scenario requires at least 2 nodes in your cluster.${NC}"
  echo -e "${RED}You have only $NODE_COUNT node(s). Cannot continue.${NC}"
  echo -e "\nCleaning up..."
  kubectl delete namespace debug-node-01
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

# Cordon the node first to prevent new pods from being scheduled
echo -e "\nCordoning the node to prevent new pod scheduling..."
kubectl cordon $TARGET_NODE

# Deploy pods directly to this node to make the impact more visible
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: node-app
  namespace: debug-node-01
spec:
  replicas: 3
  selector:
    matchLabels:
      app: node-app
  template:
    metadata:
      labels:
        app: node-app
    spec:
      nodeSelector:
        kubernetes.io/hostname: $TARGET_NODE
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: node-app-service
  namespace: debug-node-01
spec:
  selector:
    app: node-app
  ports:
  - port: 80
    targetPort: 80
EOF

echo -e "\nWaiting for pods to be scheduled on the targeted node..."
sleep 10

# Add taints to simulate NotReady condition
echo -e "\n${YELLOW}Applying NoSchedule and NoExecute taints to simulate NotReady condition...${NC}"
kubectl taint node $TARGET_NODE node.kubernetes.io/not-ready=true:NoSchedule --overwrite
kubectl taint node $TARGET_NODE node.kubernetes.io/not-ready=true:NoExecute --overwrite
kubectl taint node $TARGET_NODE node.kubernetes.io/unreachable=true:NoExecute --overwrite

# Create a DaemonSet to simulate failing kubelet on the target node
# This DaemonSet will create a pod that blocks on the target node but runs normally on others
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-problem-simulator
  namespace: debug-node-01
spec:
  selector:
    matchLabels:
      app: problem-simulator
  template:
    metadata:
      labels:
        app: problem-simulator
    spec:
      tolerations:
      - key: node.kubernetes.io/not-ready
        operator: Exists
        effect: NoSchedule
      - key: node.kubernetes.io/unreachable
        operator: Exists
        effect: NoSchedule
      containers:
      - name: node-status-reporter
        image: busybox
        command: ["/bin/sh", "-c"]
        args:
        - |
          if [ "\$(hostname)" = "$TARGET_NODE" ] || [[ "\$(hostname)" == *"$TARGET_NODE"* ]]; then
            echo "Simulating node problems on \$(hostname)..."
            # Endless sleep to simulate a stuck process
            while true; do
              sleep 3600
            done
          else
            echo "Running normally on \$(hostname)..."
            # Healthy behavior on other nodes
            while true; do
              sleep 10
              echo "Node is healthy"
            done
          fi
EOF

# Modify the status directly for immediate effect (this is more aggressive than patch)
echo -e "\n${YELLOW}Using direct API access to mark node as NotReady...${NC}"

# Get API server details
API_ENDPOINT=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}')
TOKEN=$(kubectl get secrets -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='default')].data.token}" | base64 --decode)

# First, get the current node status
NODE_JSON=$(kubectl get node $TARGET_NODE -o json)

# Modify the conditions to mark Ready as False
MODIFIED_JSON=$(echo $NODE_JSON | sed 's/"type":"Ready","status":"True"/"type":"Ready","status":"False"/g')

# Replace the node status directly through the API
curl --insecure -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$MODIFIED_JSON" \
  $API_ENDPOINT/api/v1/nodes/$TARGET_NODE/status

# Use kubectl directly to force the status change (more reliable method)
echo -e "\n${YELLOW}Using kubectl to force the node to NotReady status...${NC}"
kubectl get node $TARGET_NODE -o yaml | sed 's/type: Ready/type: NotReady/g' | kubectl replace --force -f -

# Using multiple methods for patching node conditions to show NotReady status
echo -e "\n${YELLOW}Patching node conditions to show NotReady status (multiple methods)...${NC}"
kubectl patch node $TARGET_NODE -p '{"status":{"conditions":[{"type":"Ready","status":"False","reason":"KubeletNotReady","message":"Kubelet stopped posting node status."}]}}'

# Create a DaemonSet that makes a fake kubelet that reports NotReady
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fake-kubelet
  namespace: debug-node-01
spec:
  selector:
    matchLabels:
      name: fake-kubelet
  template:
    metadata:
      labels:
        name: fake-kubelet
    spec:
      tolerations:
      - operator: Exists
      containers:
      - name: fake-kubelet
        image: curlimages/curl
        command: ["/bin/sh", "-c"]
        args:
        - |
          if [ "\$(NODE_NAME)" = "$TARGET_NODE" ]; then
            echo "Starting fake kubelet on target node"
            while true; do
              sleep 60
            done
          else
            echo "Running on non-target node, sleeping"
            sleep infinity
          fi
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
EOF

print_separator
echo -e "${GREEN}Node Not Ready Scenario Deployed!${NC}"
print_separator
echo -e "\n${YELLOW}Important Note:${NC}"
echo -e "If the node is still showing as Ready, please manually set it as NotReady with:"
echo -e "${GREEN}kubectl get node $TARGET_NODE -o yaml | sed 's/type: Ready/type: NotReady/g' | kubectl replace --force -f -${NC}"
echo -e "\nOr cordon and taint the node with:"
echo -e "${GREEN}kubectl cordon $TARGET_NODE${NC}"
echo -e "${GREEN}kubectl taint node $TARGET_NODE node.kubernetes.io/not-ready=true:NoExecute${NC}"
echo -e "\n${YELLOW}Scenario Setup:${NC}"
echo -e "* Node ${TARGET_NODE} should be marked as NotReady"
echo -e "* If not, use the manual commands above"
echo -e "* Applications have been deployed across the cluster including the affected node"
echo -e "* Pods on the affected node will eventually be evicted"
echo -e "\n${YELLOW}Diagnosis Steps:${NC}"
echo -e "1. Check node status: ${GREEN}kubectl get nodes${NC}"
echo -e "2. Examine the problematic node: ${GREEN}kubectl describe node $TARGET_NODE${NC}"
echo -e "3. Check pod status across the cluster: ${GREEN}kubectl get pods -n debug-node-01 -o wide${NC}"
echo -e "4. Observe the impact on workloads: ${GREEN}kubectl get events -n debug-node-01${NC}"
echo -e "\n${YELLOW}Expected Observations:${NC}"
echo -e "* Node $TARGET_NODE will show NotReady status"
echo -e "* Pods on this node will remain in 'Unknown' or 'Terminating' state"
echo -e "* New pods scheduled to this node will remain 'Pending'"
echo -e "* Events will show node-related issues and pod evictions"
echo -e "\n${YELLOW}Your task:${NC} Diagnose the issue, determine the root cause, and resolve it."
echo -e "When you're ready to restore the node, run the cleanup script: ${GREEN}./cleanup.sh${NC}"
print_separator 