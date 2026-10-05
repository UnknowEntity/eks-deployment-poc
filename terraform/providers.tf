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