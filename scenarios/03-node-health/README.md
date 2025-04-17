# Kubernetes Node Health Troubleshooting Scenarios

This directory contains scenarios focused on node health issues in Kubernetes clusters.

## Available Scenarios

### [Scenario 01: Node Not Ready](./scenario-01/)

**Issue:** A node in the cluster enters NotReady state, causing pod evictions and scheduling problems.

**Learning Focus:** Understanding the Kubernetes node health subsystem, kubelet functionality, and node diagnostics.

**Skills Practiced:**
- Debugging node conditions
- Interpreting kubelet logs
- Understanding node resource constraints
- Analyzing system daemon status
- Resolving common node failures

## Running the Scenarios

Each scenario contains:
- A deployment script (`deploy.sh`) to set up the scenario
- A cleanup script (`cleanup.sh`) to remove all created resources
- A description of the symptoms in `symptoms.md`
- Solutions and explanations in `solutions.md`

To run a scenario:

1. Navigate to the scenario directory
   ```bash
   cd scenario-01
   ```

2. Deploy the scenario
   ```bash
   ./deploy.sh
   ```

3. Follow the symptom descriptions and try to diagnose and fix the issue
   
4. When you're done, clean up the resources
   ```bash
   ./cleanup.sh
   ```

## Required Tools

- Kubernetes cluster (minikube, kind, Docker Desktop, or a cloud provider)
- `kubectl` CLI tool
- Basic understanding of Kubernetes node architecture 