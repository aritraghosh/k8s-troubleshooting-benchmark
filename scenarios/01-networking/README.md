# Kubernetes Networking Troubleshooting Scenarios

This directory contains scenarios focused on network connectivity issues in Kubernetes clusters.

## Available Scenarios

### [Scenario 01: Service Connection Failure](./scenario-01/)

**Issue:** Service selector does not match pod labels, causing connection failures.

**Learning Focus:** Understanding how Kubernetes services use label selectors to route traffic to pods, and how to troubleshoot connection issues between services.

**Skills Practiced:**
- Checking service endpoints
- Verifying label selectors
- Inspecting port configurations
- Testing connectivity between pods and services

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
- Basic understanding of Kubernetes networking concepts 