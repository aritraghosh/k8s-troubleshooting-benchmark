# Networking Troubleshooting Solutions

# Scenario 01: Service Connection Failure (Service Endpoint Mismatch)

The issue in this debugging scenario is a label mismatch between the service selector and pod labels:

1. The data-service pods are labeled with `tier: data`
2. The data-service service is selecting pods with `tier: database`
3. Due to this mismatch, the service has no endpoints, resulting in connection failures

## Analysis

This is a common issue in Kubernetes deployments because:

1. The error is subtle - the label mismatch is easy to miss
2. All components appear to be running correctly
3. Services will exist even if they have no endpoints
4. Direct access to pods works fine, making it seem like a network issue

## Solution

The fix would be to update the service selector to match the pod labels:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: data-service
  namespace: debug-svc-01
spec:
  selector:
    app: data-service
    tier: data  # Changed from 'database' to 'data' to match pod labels
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

Alternatively, you could update the pod labels to match the service selector:

```yaml
template:
  metadata:
    labels:
      app: data-service
      tier: database  # Changed from 'data' to 'database' to match service selector
```

## Debugging Steps

1. Check if pods are running: `kubectl get pods -n debug-svc-01`
2. Check the service: `kubectl get svc -n debug-svc-01`
3. **Critical Step**: Check if the service has endpoints: `kubectl get endpoints data-service -n debug-svc-01`
4. Examine pod labels: `kubectl get pods -l app=data-service -n debug-svc-01 --show-labels`
5. Compare the service selector with pod labels: `kubectl describe svc data-service -n debug-svc-01`

This issue highlights the importance of validating that services have endpoints, which is a common oversight in Kubernetes troubleshooting.