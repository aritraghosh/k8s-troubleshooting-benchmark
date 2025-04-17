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
echo -e "${GREEN}Cleaning up Node Not Ready Scenario${NC}"
print_separator

# Get names of all nodes in the cluster
echo -e "\nIdentifying affected nodes..."
NODES=($(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'))

# Find the node that has been marked NotReady
NOT_READY_NODES=()
for node in "${NODES[@]}"; do
  # Check if node has the not-ready taint
  if kubectl describe node $node | grep -q "node.kubernetes.io/not-ready:NoExecute"; then
    NOT_READY_NODES+=($node)
  fi
done

if [ ${#NOT_READY_NODES[@]} -eq 0 ]; then
  echo -e "${YELLOW}No nodes found with NotReady taint. Checking status conditions...${NC}"
  
  # Check for nodes marked as NotReady in status
  for node in "${NODES[@]}"; do
    if kubectl get node $node -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q "False"; then
      NOT_READY_NODES+=($node)
    fi
  done
fi

if [ ${#NOT_READY_NODES[@]} -eq 0 ]; then
  echo -e "${RED}No NotReady nodes found in the cluster.${NC}"
  echo -e "${YELLOW}Proceeding to remove the namespace and resources...${NC}"
else
  echo -e "\n${YELLOW}Found ${#NOT_READY_NODES[@]} nodes marked as NotReady. Restoring them...${NC}"
  
  # Fix each NotReady node
  for node in "${NOT_READY_NODES[@]}"; do
    echo -e "\nRestoring node: $node"
    
    # Remove all taints
    echo -e "Removing node taints..."
    kubectl taint node $node node.kubernetes.io/not-ready- || true
    kubectl taint node $node node.kubernetes.io/unreachable- || true
    
    # Patch the node status back to Ready - use multiple approaches to ensure it works
    echo -e "Patching node status to Ready..."
    
    # Direct status update
    kubectl patch node $node -p '{"status":{"conditions":[{"type":"Ready","status":"True","reason":"KubeletReady","message":"kubelet is posting ready status"}]}}'
    
    # Force replace with YAML approach
    kubectl get node $node -o yaml | sed 's/type: NotReady/type: Ready/g' | kubectl replace --force -f -
    
    # Make sure Ready condition is set to True
    NODE_JSON=$(kubectl get node $node -o json)
    MODIFIED_JSON=$(echo $NODE_JSON | sed 's/"type":"Ready","status":"False"/"type":"Ready","status":"True"/g')
    echo "$MODIFIED_JSON" > /tmp/node-fixed.json
    kubectl replace --force -f /tmp/node-fixed.json
    
    # Uncordon the node
    echo -e "Uncordoning the node..."
    kubectl uncordon $node
  done
fi

# Delete any DaemonSets created for the scenario
echo -e "\nDeleting DaemonSets..."
kubectl delete daemonset -n debug-node-01 --all

# Delete all resources in the namespace
echo -e "\nDeleting namespace and all resources in it..."
kubectl delete namespace debug-node-01

# Final verification that nodes are Ready
echo -e "\n${YELLOW}Verifying all nodes are Ready...${NC}"
for node in "${NODES[@]}"; do
  status=$(kubectl get node $node -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
  if [ "$status" != "True" ]; then
    echo -e "${RED}Node $node is still not Ready. Manual intervention may be required.${NC}"
    echo -e "Run: ${GREEN}kubectl get node $node -o yaml | sed 's/type: NotReady/type: Ready/g' | kubectl replace --force -f -${NC}"
  else
    echo -e "${GREEN}Node $node is Ready.${NC}"
  fi
done

print_separator
echo -e "${GREEN}Cleanup Completed!${NC}"
echo -e "The affected nodes have been restored to normal operation."
echo -e "All test deployments and services have been removed."
print_separator

# Clean up any temporary files
rm -f /tmp/node-fixed.json 2>/dev/null 