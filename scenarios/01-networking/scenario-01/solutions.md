# Solutions: Service Connection Failure (Scenario 01)

## Root Cause

The root cause of the issue is a **label mismatch** between the service selector and the pod labels:

- The data service pods have the label `tier: data`
- The Kubernetes service is selecting pods with the label `tier: database`

Due to this mismatch, the service does not have any endpoints associated with it, resulting in connection timeouts when the client tries to access the service.

## How to Verify the Issue

1. Check if the service has endpoints:
```bash
kubectl get endpoints data-service -n debug-svc-01
```
If the output shows no endpoints (addresses), this confirms the service is not selecting any pods.

2. Verify the labels on the pods:
```bash
kubectl get pods -n debug-svc-01 --show-labels
```
You should see that the pods have the label `tier=data`.

3. Check the service configuration:
```bash
kubectl describe svc data-service -n debug-svc-01
```
Notice the selector is set to `tier=database` instead of `tier=data`.

## Solution

Edit the service configuration to match the pod labels by changing the selector:

```bash
kubectl edit svc data-service -n debug-svc-01
```

Change the selector from:
```yaml
selector:
  tier: database
```

To:
```yaml
selector:
  tier: data
```

After saving the changes, the service should immediately recognize the pods as endpoints. Verify with:
```bash
kubectl get endpoints data-service -n debug-svc-01
```

The output should now show the IP addresses of the pods, indicating that the service has properly selected them.

## Alternative Solutions

1. **Update pod labels**: Instead of changing the service selector, you could also update the pod labels to match the service selector. This would involve editing the deployment:
```bash
kubectl edit deployment data-service -n debug-svc-01
```
And changing the pod template labels from `tier: data` to `tier: database`.

2. **Create a new service**: If you can't modify the existing service, you could create a new service with the correct selector:
```bash
kubectl create service clusterip data-service-fixed -n debug-svc-01 --tcp=80:80 --dry-run=client -o yaml | sed 's/app: data-service-fixed/tier: data/' | kubectl apply -f -
```

## Best Practices to Avoid This Issue

1. Use consistent labeling conventions across your resources
2. Implement CI/CD validation that checks for label consistency between services and deployments
3. Use tools like `kubectl get endpoints` as part of your deployment verification
4. Consider using Kubernetes network policies to explicitly allow traffic, which can help identify connectivity issues
5. Use Helm or Kustomize templates to ensure service selectors match deployment labels 