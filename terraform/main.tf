locals {
  lb_controller_service_account_name = "aws-load-balancer-controller"
  name_space                         = "kube-system"
  cluster_name                       = "basic-cluster"
}

module "aws" {
  source = "./aws"
  tags = {
    GithubRepo = "eks-deployment-poc"
    GithubOrg  = "UnknowEntity"
  }

  cluster_name                       = local.cluster_name
  name_space                         = local.name_space
  lb_controller_service_account_name = local.lb_controller_service_account_name

  # Sensitive information
  admin_cidrs              = var.admin_cidrs
  provider_assume_role_arn = var.provider_assume_role_arn
}