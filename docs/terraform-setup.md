# Terraform Setup

This guide uses the Terraform configuration in `terraform/` to create and
manage the EKS environment. In this repository, Terraform installs the AWS
Load Balancer Controller and configures EKS Pod Identity for its ServiceAccount.

The ECR repository and the GitHub Actions OIDC role are **not** part of this
configuration. They live in `terraform-ci/` so CI can run without the cost of
the cluster. Apply `terraform-ci/` first; see the [CI guide](ci.md).

## Prerequisites

- Terraform 1.2 or later.
- AWS CLI configured with credentials that can assume the IAM role specified
  by `provider_assume_role_arn`.
- An AWS CLI profile for EKS authentication, as set by `aws_profile`.
- The role must have the AWS permissions required to create and manage the
  infrastructure in this configuration.

Terraform creates a VPC with a NAT Gateway, an EKS cluster and managed node
group, and the controller's Pod Identity resources. These resources can incur
AWS charges.

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

## Standard Terraform workflow

Use this workflow for every change to `terraform/` and `terraform-ci/`, run from
the directory of the stack you are changing. Terraform is run locally and
deliberately, rather than from CI, because changes are infrequent and you keep
full control over what is applied.

1. Initialize providers and modules:

   ```bash
   terraform init
   ```

2. Check the configuration is valid:

   ```bash
   terraform validate
   ```

3. Save a plan:

   ```bash
   terraform plan -out=tfplan
   ```

4. Export the plan as plain text for review:

   ```bash
   terraform show -no-color tfplan > tfplan.txt
   ```

5. Review `tfplan.txt` manually. Confirm it targets the intended AWS account and
   region, and that nothing is replaced or destroyed unexpectedly.
6. Apply exactly the plan you reviewed:

   ```bash
   terraform apply tfplan
   ```

7. After the change is applied and working, format the code and commit:

   ```bash
   terraform fmt
   git add . && git commit
   ```

Formatting comes last on purpose: it avoids churn while you iterate, and it only
changes whitespace in code you have already proven works.

`tfplan` and `tfplan.txt` are gitignored but can contain sensitive values. Do not
share them, and delete them once the plan has been applied. If the configuration
changes after planning, create a new plan instead of applying the old one.

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

From the `terraform/` directory, follow the same
[standard workflow](#standard-terraform-workflow), using a destroy plan, and
review what Terraform will remove:

```bash
terraform plan -destroy -out=tfplan
terraform show -no-color tfplan > tfplan.txt
```

If the plan is expected, destroy the Terraform-managed infrastructure:

```bash
terraform apply tfplan
```

Review the plan before applying. This removes
Terraform-managed resources, including the EKS cluster, VPC, NAT Gateway,
and controller resources. The ECR repository and CI role are managed by
`terraform-ci/` and are untouched; destroy them separately from that directory
(this also deletes the images) when you no longer need CI. Run the shared
cleanup checks afterward and review any AWS resources that remain.
