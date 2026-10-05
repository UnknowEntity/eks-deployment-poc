# Manual Setup

This guide creates the EKS cluster and supporting AWS Load Balancer Controller
resources using AWS CLI, `eksctl`, and Helm. It follows the manual path
described in [Setup and Cleanup](setup-and-cleanup.md), which uses IRSA for
workload access to AWS.

## Prerequisites

Install and configure:

- AWS CLI with credentials and permissions to create the required AWS
  resources.
- `eksctl`, `kubectl`, and Helm.
- An AWS region and account to use for the cluster.

The commands below use the cluster name and region from
`manual_setup/cluster.yaml` (`basic-cluster` and `ap-southeast-1`). Update that
configuration if you want to use different values.

### Configure an AWS CLI profile

For long-running `eksctl` commands, you can configure a profile that refreshes
credentials through your existing AWS CLI profile. Add this to `~/.aws/config`,
replacing the profile name and region:

```toml
[profile eksctl]
credential_process = aws configure export-credentials --profile <your-main-profile> --format process
region = <region>
```

Select the profile in your shell before running AWS commands:

```bash
export AWS_PROFILE=eksctl
```

In PowerShell, use:

```powershell
$env:AWS_PROFILE = "eksctl"
```

## Create the cluster

From the repository root, validate the `eksctl` configuration:

```bash
eksctl create cluster -f manual_setup/cluster.yaml --dry-run
```

If the configuration is correct, create the cluster:

```bash
eksctl create cluster -f manual_setup/cluster.yaml
```

Configure `kubectl` to use the new cluster and verify its nodes:

```bash
aws eks --region ap-southeast-1 update-kubeconfig --name basic-cluster
kubectl get nodes
```

## Create the ECR repository

Create the application repository if it does not already exist:

```bash
aws ecr describe-repositories --repository-names hello-world-go
```

If it does not exist, create it:

```bash
aws ecr create-repository --repository-name hello-world-go
```

## Install the AWS Load Balancer Controller with IRSA

The application Service uses `type: LoadBalancer`. Install the AWS Load
Balancer Controller so Kubernetes can provision and manage its AWS load
balancer.

Download the controller IAM policy and create a customer-managed policy:

```bash
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AmazonEKSLoadBalancerControllerPolicy \
  --policy-document file://iam_policy.json
```

Associate an IAM OIDC provider with the cluster:

```bash
eksctl utils associate-iam-oidc-provider \
  --region ap-southeast-1 \
  --cluster basic-cluster \
  --approve
```

Create the controller IAM role and Kubernetes ServiceAccount using IRSA:

```bash
eksctl create iamserviceaccount \
  --cluster basic-cluster \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn arn:aws:iam::<account-id>:policy/AmazonEKSLoadBalancerControllerPolicy \
  --approve
```

Replace `<account-id>` with your AWS account ID.

Install the controller with Helm, using the ServiceAccount created above:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=basic-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

Verify that the controller is ready:

```bash
kubectl get deployment aws-load-balancer-controller -n kube-system
kubectl get pods -n kube-system
```

After setup, follow the [application deployment guide](deployment.md) to
generate the application Secret, push an image, and deploy the application.

## Cleanup

Before deleting the cluster, delete all Kubernetes Services of type
`LoadBalancer` and wait until their AWS load balancers are gone. Follow the
[shared cleanup checks](setup-and-cleanup.md#shared-cleanup-checks) for the
required checks and warnings, then delete the manually created resources as
appropriate.

Delete the `eksctl`-managed cluster after load balancer cleanup has completed:

```bash
eksctl delete cluster \
  --region ap-southeast-1 \
  --name basic-cluster \
  --disable-nodegroup-eviction
```

The IAM policy created above is customer-managed and may remain after cluster
deletion. If it is no longer used by any role, remove it separately according
to your AWS account's IAM cleanup process:

```bash
aws iam delete-policy \
  --policy-arn arn:aws:iam::<account-id>:policy/AmazonEKSLoadBalancerControllerPolicy
```

The ECR repository is also independent of the cluster. If it and its images are
no longer needed, delete it explicitly:

```bash
aws ecr delete-repository \
  --repository-name hello-world-go \
  --force
```

The `--force` option deletes the repository and all images in it. Finish by
running the [shared cleanup checks](setup-and-cleanup.md#shared-cleanup-checks).
