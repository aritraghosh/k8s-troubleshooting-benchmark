#!/bin/bash
#
# Cleanup script for the Service Endpoint Mismatch scenario
# This script removes all resources created by the deploy.sh script
#

# Print a horizontal separator line
print_separator() {
  echo "======================================================================"
}

print_separator
echo "CLEANING UP SERVICE ENDPOINT MISMATCH SCENARIO"
print_separator
echo

# Delete namespace and all resources in it
echo "Deleting namespace debug-svc-01 and all resources in it..."
kubectl delete namespace debug-svc-01

echo
print_separator
echo "CLEANUP COMPLETE"
print_separator 