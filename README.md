# AWS-K3s-Deployment-portfolio

This project provisions a two-subnet AWS VPC to simulate a production and development environment using Terraform. It deploys a minimal Flask app via Docker to a K3s (lightweight Kubernetes) cluster running on EC2 instances.

## Architecture

- **Terraform**: Provisions the VPC, subnets, security groups, and EC2 instances.
- **K3s**: Lightweight Kubernetes cluster.
- **Docker + Flask**: Simple containerized web app.

## Subnet Simulation

- `dev-subnet`: Hosts the worker node.
- `prod-subnet`: Hosts the master node.

## Resources

- https://aws.amazon.com/getting-started/
- https://docs.aws.amazon.com/
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- https://docs.k3s.io/quick-start
- https://docs.docker.com/get-started/workshop/
- https://hub.docker.com/_/python
- https://flask.palletsprojects.com/en/stable/

## To Go Further

- Using GitHub Workflows to deploy using the correct manifests (dev or prod) depending on the branch?