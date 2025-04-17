#!/bin/bash
#
# Deployment script for the Service Endpoint Mismatch scenario
# This script creates the namespace and applies all necessary resources
#

# Print a horizontal separator line
print_separator() {
  echo "======================================================================"
}

print_separator
echo "DEPLOYING SERVICE ENDPOINT MISMATCH SCENARIO"
print_separator
echo

# Create namespace for all resources in this scenario
echo "Creating namespace: debug-svc-01"
kubectl create namespace debug-svc-01

# Apply all manifests in the correct order
echo "Applying ConfigMaps..."
kubectl apply -f manifests/configs.yaml

echo "Applying backend service and deployment..."
kubectl apply -f manifests/backend.yaml
kubectl apply -f manifests/service.yaml

echo "Applying client application..."
kubectl apply -f manifests/client.yaml

# Wait for pods to be ready to make testing easier
echo
echo "Waiting for pods to start..."
kubectl wait --for=condition=ready pod -l app=data-service -n debug-svc-01 --timeout=60s || true
kubectl wait --for=condition=ready pod -l app=client-app -n debug-svc-01 --timeout=60s || true

print_separator
echo "DEPLOYMENT COMPLETE"
print_separator
echo

cat << EOF
To observe the issue:

1. Check if pods are running:
   kubectl get pods -n debug-svc-01

2. Check the service:
   kubectl get svc -n debug-svc-01

3. Check if the service has endpoints (this is where you'll see the issue):
   kubectl get endpoints -n debug-svc-01

4. Try to access the client application:
   kubectl port-forward svc/client-service -n debug-svc-01 9090:80
   Then visit http://localhost:9090 in your browser

5. Note the connection error to the data service

To test direct access to the data service pod (which should work):
   kubectl port-forward \$(kubectl get pod -l app=data-service -n debug-svc-01 -o jsonpath='{.items[0].metadata.name}') 8081:80 -n debug-svc-01
   Then visit http://localhost:8081 in your browser

You should see the client can't connect to the data service, 
even though the data service pods are running.

This is the issue to debug!
EOF 