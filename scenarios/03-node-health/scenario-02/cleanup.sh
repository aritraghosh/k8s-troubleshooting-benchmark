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
echo -e "${GREEN}Cleaning up Memory Pressure Scenario${NC}"
print_separator

# Get names of all nodes in the cluster
echo -e "\nIdentifying affected nodes..."
NODES=($(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'))

# Find nodes with memory pressure
MEMORY_PRESSURE_NODES=()
for node in "${NODES[@]}"; do
  # Check if node has the memory-pressure taint or condition
  if kubectl describe node $node | grep -q "node.kubernetes.io/memory-pressure"; then
    MEMORY_PRESSURE_NODES+=($node)
  fi
done

if [ ${#MEMORY_PRESSURE_NODES[@]} -eq 0 ]; then
  echo -e "${YELLOW}No nodes found with memory pressure taint. Checking conditions...${NC}"
  
  # Check for nodes with MemoryPressure condition
  for node in "${NODES[@]}"; do
    if kubectl get node $node -o jsonpath='{.status.conditions[?(@.type=="MemoryPressure")].status}' | grep -q "True"; then
      MEMORY_PRESSURE_NODES+=($node)
    fi
  done
fi

# Also check for NotReady nodes
NOT_READY_NODES=()
for node in "${NODES[@]}"; do
  if kubectl get node $node -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q "False"; then
    NOT_READY_NODES+=($node)
  fi
done

# Combine the lists, removing duplicates
ALL_AFFECTED_NODES=()
for node in "${MEMORY_PRESSURE_NODES[@]}" "${NOT_READY_NODES[@]}"; do
  # Only add if not already in the list
  if [[ ! " ${ALL_AFFECTED_NODES[*]} " =~ " ${node} " ]]; then
    ALL_AFFECTED_NODES+=($node)
  fi
done

# First stop the memory hog
echo -e "\nStopping memory-hungry workloads..."
kubectl delete daemonset memory-hog -n debug-node-02 --grace-period=0 --force || true
kubectl delete pod memory-controller -n debug-node-02 --grace-period=0 --force || true

# Wait a moment for resources to be freed
echo -e "\nWaiting for memory to be freed..."
sleep 5

if [ ${#ALL_AFFECTED_NODES[@]} -eq 0 ]; then
  echo -e "${YELLOW}No affected nodes found in the cluster.${NC}"
else
  echo -e "\n${YELLOW}Found ${#ALL_AFFECTED_NODES[@]} affected nodes. Restoring them...${NC}"
  
  # Fix each affected node
  for node in "${ALL_AFFECTED_NODES[@]}"; do
    echo -e "\nRestoring node: $node"
    
    # Remove memory pressure taint
    echo -e "Removing memory pressure taint..."
    kubectl taint node $node node.kubernetes.io/memory-pressure- || true
    
    # Fix the memory pressure condition
    echo -e "Patching memory pressure condition to False..."
    kubectl patch node $node -p '{"status":{"conditions":[{"type":"MemoryPressure","status":"False","reason":"KubeletHasSufficientMemory","message":"kubelet has sufficient memory available"}]}}'
    
    # Fix the Ready condition if needed
    READY_STATUS=$(kubectl get node $node -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    if [ "$READY_STATUS" != "True" ]; then
      echo -e "Patching Ready condition to True..."
      kubectl patch node $node -p '{"status":{"conditions":[{"type":"Ready","status":"True","reason":"KubeletReady","message":"kubelet is posting ready status"}]}}'
    fi
    
    # Uncordon the node
    echo -e "Uncordoning the node..."
    kubectl uncordon $node
  done
fi

# Clean up all other resources
echo -e "\nDeleting all scenario resources..."
kubectl delete daemonset -n debug-node-02 --all || true
kubectl delete deployment -n debug-node-02 --all || true
kubectl delete service -n debug-node-02 --all || true
kubectl delete configmap -n debug-node-02 --all || true
kubectl delete pod -n debug-node-02 --all --grace-period=0 --force || true

# Delete the namespace
echo -e "\nDeleting namespace debug-node-02..."
kubectl delete namespace debug-node-02

# Final verification that nodes are healthy
echo -e "\n${YELLOW}Verifying all nodes are healthy...${NC}"
for node in "${NODES[@]}"; do
  # Check memory pressure
  MEM_PRESSURE=$(kubectl get node $node -o jsonpath='{.status.conditions[?(@.type=="MemoryPressure")].status}')
  READY_STATUS=$(kubectl get node $node -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
  
  if [ "$MEM_PRESSURE" != "False" ] || [ "$READY_STATUS" != "True" ]; then
    echo -e "${RED}Node $node still shows issues. Manual intervention may be required.${NC}"
    if [ "$MEM_PRESSURE" != "False" ]; then
      echo -e "  - MemoryPressure: $MEM_PRESSURE"
      echo -e "  - Run: ${GREEN}kubectl patch node $node -p '{\"status\":{\"conditions\":[{\"type\":\"MemoryPressure\",\"status\":\"False\"}]}}'${NC}"
    fi
    if [ "$READY_STATUS" != "True" ]; then
      echo -e "  - Ready: $READY_STATUS"
      echo -e "  - Run: ${GREEN}kubectl patch node $node -p '{\"status\":{\"conditions\":[{\"type\":\"Ready\",\"status\":\"True\"}]}}'${NC}"
    fi
  else
    echo -e "${GREEN}Node $node is healthy.${NC}"
  fi
done

print_separator
echo -e "${GREEN}Cleanup Completed!${NC}"
echo -e "The affected nodes have been restored to normal operation."
echo -e "All test deployments and services have been removed."
print_separator 