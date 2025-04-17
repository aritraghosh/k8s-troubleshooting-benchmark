# Scenario 01: Application Repeatedly Crashing with OOMKilled

## Symptoms

* The main application pod keeps restarting
* Pod status shows "CrashLoopBackOff"
* Checking pod logs shows the container was terminated due to OOMKilled
* The application has high memory usage
* Other pods in the cluster are running normally

## Expected Behavior

The memory-intensive application should start successfully and remain in Running state, processing data without being terminated.

## Observed Behaviors

* Pod starts successfully but terminates after a few seconds to minutes
* Kubernetes events show "OOMKilled" as the reason for termination
* Pod repeatedly restarts but never stays running
* Application logs show it starts processing data but doesn't complete
* Resource usage metrics show memory usage increasing rapidly before termination 