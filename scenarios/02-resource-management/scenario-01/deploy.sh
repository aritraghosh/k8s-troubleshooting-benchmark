#!/bin/bash

# Create namespace
kubectl create namespace debug-rm-01

# Apply manifests
kubectl apply -f manifests/deployment.yaml
kubectl apply -f manifests/service.yaml

echo ""
echo "Deployment complete!"
echo ""
echo "To observe the issue:"
echo "1. Watch the pod status: kubectl get pods -n debug-rm-01 -w"
echo "2. Check pod events: kubectl describe pod -l app=memory-intensive-app -n debug-rm-01"
echo "3. View pod logs: kubectl logs -l app=memory-intensive-app -n debug-rm-01"
echo ""
echo "You should see the pod crashing with OOMKilled status and restarting repeatedly."
echo "This is the issue to debug!" 