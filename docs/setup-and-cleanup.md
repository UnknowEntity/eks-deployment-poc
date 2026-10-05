# Setup and Cleanup

This guide introduces the two ways to set up the EKS environment in this
repository and provides shared checks for cleaning it up. Choose one setup
method:

## Setup approaches

### Manual

The manual approach uses AWS and Kubernetes command-line tools to create and
configure resources step by step. It is useful for learning how the EKS
components fit together and for seeing the effect of each operation. The
[`manual setup guide`](manual-setup.md) uses the `eksctl` cluster configuration
in `manual_setup`.

### Terraform

The Terraform approach declares infrastructure as code and uses Terraform to
create and manage the resources. It makes the infrastructure repeatable and
provides a plan to review before applying changes. See the
[`Terraform setup guide`](terraform-setup.md) for variable configuration,
planning, applying, and destroying the infrastructure.

## Workload access to AWS: IRSA or EKS Pod Identity

Kubernetes workloads that call AWS services need AWS credentials. This
repository demonstrates two ways to associate an IAM role with a Kubernetes
ServiceAccount:

- **IRSA (IAM Roles for Service Accounts)** uses the cluster's OIDC identity
  provider and a ServiceAccount annotation to let a workload assume an IAM
  role.
- **EKS Pod Identity** uses the EKS Pod Identity Agent and an association
  between a cluster, namespace, ServiceAccount, and IAM role.

These are alternative mechanisms for providing workload credentials; they are
not two steps that need to be enabled together. In this repository, the manual
AWS Load Balancer Controller instructions use IRSA, while the Terraform
configuration sets up EKS Pod Identity for that controller.

## Shared cleanup checks

Review resources after cleanup and remove any that remain to avoid ongoing AWS
charges. Set `<region>` to the AWS region used by the cluster.

Check for running EC2 instances:

```bash
aws ec2 describe-instances \
  --region <region> \
  --filters Name=instance-state-name,Values=running
```

Check for load balancers:

```bash
aws elbv2 describe-load-balancers \
  --region <region>
```

Check for NAT Gateways:

```bash
aws ec2 describe-nat-gateways \
  --region <region>
```

Check for remaining EKS clusters:

```bash
aws eks list-clusters \
  --region <region>
```

Check for ECR repositories:

```bash
aws ecr describe-repositories \
  --region <region>
```

### Remove LoadBalancer Services before deleting the cluster

Before deleting an EKS cluster, find and remove every Kubernetes Service with
`type: LoadBalancer`. Each Service may own an AWS load balancer, such as an NLB.
Deleting the cluster while a load balancer still exists can leave dependent
resources behind or cause cleanup of the cluster's subnets, VPC, or
CloudFormation resources to fail or become stuck.

List Services in every namespace:

```bash
kubectl get svc -A
```

Delete each Service whose type is `LoadBalancer`:

```bash
kubectl delete svc <service-name> -n <namespace>
```

Wait for AWS to remove the associated load balancer, then check again:

```bash
aws elbv2 describe-load-balancers \
  --region <region> \
  --query 'LoadBalancers[].LoadBalancerName' \
  --output table
```

Do not proceed with cluster or VPC teardown until the load balancer is gone.
Load balancer deletion can take time; if it remains, continue investigating
and wait for the Kubernetes Service and AWS load balancer cleanup to finish.

The dependency to keep in mind is:

```text
Kubernetes Service (type: LoadBalancer)
  |
  v
AWS Load Balancer
  |
  v
VPC Subnets
  |
  v
VPC
```

After resources have finished deleting, run the checks above again and review
any remaining resources for manual cleanup.
