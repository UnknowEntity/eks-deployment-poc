variable "admin_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to access the EKS API for the cluster"
  sensitive   = true
}

variable "provider_assume_role_arn" {
  type = string
  description = "The ARN of the role to assume for the AWS provider"
  sensitive = true
}

variable "region" {
  type        = string
  description = "The AWS region to deploy resources in"
  default     = "ap-southeast-1"
  sensitive   = false
}

variable "aws_profile" {
  type        = string
  description = "The AWS CLI profile to use"
  default     = "default"
  sensitive   = false
}

locals {
  lb_controller_service_account_name = "aws-load-balancer-controller"
  name_space = "kube-system"
  cluster_name = "basic-cluster"
}

provider "tls" {}

provider "aws" {
  region = var.region
  assume_role {
    role_arn     = var.provider_assume_role_arn
    session_name = "terraform-session-temporary"
  }
}

provider "kubernetes" {
  host                   = module.aws.cluster_endpoint
  cluster_ca_certificate = base64decode(module.aws.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", local.cluster_name, "--region", var.region, "--role-arn", var.provider_assume_role_arn, "--profile", var.aws_profile]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes = {
    host                   = module.aws.cluster_endpoint
    cluster_ca_certificate = base64decode(module.aws.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", local.cluster_name, "--region", var.region, "--role-arn", var.provider_assume_role_arn, "--profile", var.aws_profile]
      command     = "aws"
    }
  }
}

module "aws" {
  source = "./aws"
  tags = {
    GithubRepo = "terraform-aws"
    GithubOrg  = "terraform-aws-modules"
  }

  cluster_name = local.cluster_name
  name_space           = local.name_space
  ecr_repository_name = "hello-world-go"
  lb_controller_service_account_name = local.lb_controller_service_account_name

  # Sensitive information
  admin_cidrs = var.admin_cidrs
  provider_assume_role_arn = var.provider_assume_role_arn
}