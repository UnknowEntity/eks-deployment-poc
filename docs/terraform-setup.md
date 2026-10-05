# Terraform Setup

This guide uses the Terraform configuration in `terraform/` to create and
manage the EKS environment. In this repository, Terraform installs the AWS
Load Balancer Controller and configures EKS Pod Identity for its ServiceAccount.

## Prerequisites

- Terraform 1.2 or later.
- AWS CLI configured with credentials that can assume the IAM role specified
  by `provider_assume_role_arn`.
- An AWS CLI profile for EKS authentication, as set by `aws_profile`.
- The role must have the AWS permissions required to create and manage the
  infrastructure in this configuration.

Terraform creates a VPC with a NAT Gateway, an EKS cluster and managed node
group, the controller's Pod Identity resources, and the `hello-world-go` ECR
repository. These resources can incur AWS charges.

## Configure Terraform variables

From the repository root, enter the Terraform directory and copy the example
variables file:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

In PowerShell, the copy command is:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and replace the placeholders:

- `admin_cidrs`: the public IPv4 CIDR range allowed to reach the EKS API, usually
  your current public IP with a `/32` suffix.
- `provider_assume_role_arn`: the ARN of the IAM role Terraform should assume.
- `aws_profile`: the AWS CLI profile used by the Kubernetes and Helm providers
  to obtain EKS authentication tokens.

The region defaults to `ap-southeast-1`; change it in `terraform/variables.tf`
if needed. The variables file is gitignored because it can contain sensitive
account configuration. Keep it, Terraform state, and saved plan files private.

## Initialize, plan, and apply

Initialize Terraform and review the proposed infrastructure changes:

```bash
terraform init
terraform plan
```

Apply the plan after confirming it targets the intended AWS account and region:

```bash
terraform apply
```

Terraform displays the changes and asks for confirmation before applying.

### Optional: save and inspect a plan

To save a plan for inspection before applying that exact plan:

```bash
terraform plan -out=tfplan
terraform show tfplan
```

For a plain-text file that is easier to review:

```bash
terraform show -no-color tfplan > tfplan.txt
```

Review the output before applying. Saved plans and their text output can contain
sensitive values; do not commit or share them. Apply the saved plan with:

```bash
terraform apply tfplan
```

## Connect to the cluster

The Terraform configuration names the cluster `basic-cluster` and defaults to
region `ap-southeast-1`. Set up `kubectl` access using the profile configured in
`terraform.tfvars`:

```bash
aws eks update-kubeconfig \
  --region ap-southeast-1 \
  --name basic-cluster \
  --profile <aws_profile> \
  --role-arn <provider_assume_role_arn>
```

Replace the placeholders with the values from `terraform.tfvars`, then verify
access:

```bash
kubectl get nodes
```

After setup, follow the [application deployment guide](deployment.md) to
generate the application Secret, push an image, and deploy the application.

## Cleanup with Terraform destroy

Before destroying the infrastructure, delete any application
`LoadBalancer` Services and wait until their AWS load balancers have been
removed. Follow the [shared cleanup checks](setup-and-cleanup.md#shared-cleanup-checks).
A remaining load balancer can block or stall cleanup of dependent networking
resources.

From the `terraform/` directory, review what Terraform will destroy:

```bash
terraform plan -destroy
```

If the plan is expected, destroy the Terraform-managed infrastructure:

```bash
terraform destroy
```

Review the proposed deletions and confirm when prompted. This removes
Terraform-managed resources, including the EKS cluster, VPC, NAT Gateway,
controller resources, and ECR repository. The repository is configured to allow
force deletion, so its images will be deleted as well. Run the shared cleanup
checks afterward and review any AWS resources that remain.
