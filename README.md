# Learning EKS

This repository is a hands-on exercise for setting up an Amazon EKS environment
and deploying the `hello-world-go` application.

## Prerequisites

Install the tools for the setup method you plan to use:

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [eksctl](https://docs.aws.amazon.com/eks/latest/eksctl/installation.html) (manual setup only)
- [Kubernetes tools](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/) (required for manual setup; optional for Terraform)
- [Terraform](https://developer.hashicorp.com/terraform/install) (Terraform setup only)

Install a container tool to build and push the application image. Choose one:

- [Docker Engine](https://docs.docker.com/engine/install/)
- [Docker Desktop for Windows](https://docs.docker.com/desktop/setup/install/windows-install/) (optional)
- [Podman Desktop](https://podman-desktop.io/docs/installation)

### Using Podman Desktop and Podman in WSL

To use Podman in both Windows and WSL with Podman Desktop, install and configure
`podman-remote`.

In Windows, run:

```powershell
podman version
```

This installs or updates the corresponding `podman-remote` version and verifies
that it is configured.

In WSL, download and install the matching remote client:

```bash
# Download and extract the podman-remote binary for WSL
curl -L https://github.com/containers/podman/releases/download/<version>/podman-remote-static-linux_amd64.tar.gz -o /tmp/podman.tar.gz

# Unpack the downloaded tarball
tar -xzf /tmp/podman.tar.gz -C /tmp

# Install it in a directory on PATH
sudo mv /tmp/bin/podman-remote-static-linux_amd64 /usr/local/bin/podman
sudo chmod +x /usr/local/bin/podman

# Verify the installation
podman version
```

## Setup & Cleanup

Choose either the manual or Terraform approach for creating the infrastructure.
The shared guide covers both approaches, explains IRSA and EKS Pod Identity, and
includes cleanup checks and warnings about removing LoadBalancer Services before
tearing down the cluster.

See the [Setup and Cleanup guide](docs/setup-and-cleanup.md).

## Deployment

Once the cluster and ECR repository are ready, follow the application deployment
guide to generate and apply the Secret, push an image, update `deployment.yaml`,
and deploy the application.

See the [Application Deployment guide](docs/deployment.md).
