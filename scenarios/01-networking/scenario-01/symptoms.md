# Scenario 02: Service Connection Failure

## Symptoms

* A data service application is deployed to the cluster
* The data service pods are running correctly (Status: Running)
* A client application attempting to connect to the data service times out
* No error messages in any of the pod logs
* All Kubernetes resources (pods, services, deployments) show as healthy

## Expected Behavior

When the client application makes a request to the data service, it should receive a successful JSON response with data.

## Observed Behaviors

* Client application shows connection timeout errors when trying to reach the data service
* Direct access to the data service pods via port-forwarding works correctly
* The data service has been verified to work when accessed directly (using port-forward to a pod)
* The service resource exists in Kubernetes and appears properly configured
* No network policies or other security mechanisms are blocking the traffic

## Key Debugging Steps

1. Check if pods are running (`kubectl get pods`)
2. Examine service configuration (`kubectl describe svc data-service`)
3. Check service endpoints (`kubectl get endpoints data-service`)
4. Verify pod labels match service selectors (`kubectl get pods --show-labels`)
5. Test direct pod access via port-forwarding 