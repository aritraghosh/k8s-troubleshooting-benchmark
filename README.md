# Kubernetes Troubleshooting Benchmark

A collection of intentionally broken Kubernetes scenarios designed to help you practice and improve your Kubernetes troubleshooting skills.

## Overview

This repository contains various Kubernetes scenarios with intentional issues that you need to troubleshoot and fix. Each scenario is designed to simulate real-world problems that Kubernetes administrators and developers might encounter.

## Prerequisites

- Kubernetes cluster (local or remote)
- kubectl configured to access your cluster
- Basic understanding of Kubernetes concepts

## Scenario Categories

The scenarios are organized into different categories based on the type of issue:

### 1. Networking

Scenarios related to networking issues, including services, ingress, DNS, and network policies.

- [Scenario 01: Service Connection Failure](scenarios/01-networking/scenario-01/)

### 2. Resource Management

Scenarios related to resource limits, requests, quotas, and autoscaling.

- [Scenario 01: Application Repeatedly Crashing with OOMKilled](scenarios/02-resource-management/scenario-01/)

### 3. Node Health

Scenarios related to node availability, health checks, and resource constraints.

- [Scenario 01: Node Not Ready](scenarios/03-node-health/scenario-01/)
- [Scenario 02: Node Memory Pressure](scenarios/03-node-health/scenario-02/)

## How to Use

Each scenario has its own directory with the following structure:

```
scenarios/
├── category/
│   ├── scenario-xx/
│   │   ├── deploy.sh         # Script to deploy the scenario
│   │   ├── cleanup.sh        # Script to clean up the scenario
│   │   ├── symptoms.md       # Description of the symptoms and expected behavior
│   │   └── manifests/        # Kubernetes manifests with intentional issues
```

To deploy a scenario:

1. Navigate to the scenario directory
2. Run the deploy script: `./deploy.sh`
3. Investigate the issues based on the symptoms described in `symptoms.md`
4. Try to fix the issues
5. When done, run the cleanup script: `./cleanup.sh`

## Solutions

Solutions for each scenario are provided in the `solutions` directory but try to solve the issues yourself before looking at the solutions.

## Contributing

Contributions are welcome! If you have ideas for new scenarios or improvements to existing ones, please submit a pull request or create an issue.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
