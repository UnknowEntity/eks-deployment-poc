# AWS Provider Configuration
variable "provider_assume_role_arn" {
  type = string
  description = "The ARN of the role to assume for the AWS provider"
  sensitive = true
}

variable "admin_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to access the EKS API"
  sensitive   = true
}

# EKS
variable "cluster_name" {
  type = string
  description = "The name of the EKS cluster"
  sensitive = false
}

variable "name_space" {
  type = string
  description = "The namespace for the EKS resources"
  sensitive = false
}

variable "tags" {
  type = map(string)
  description = "A map of tags to apply to AWS resources"
  sensitive = false
}

variable "lb_controller_service_account_name" {
  type = string
  description = "The name of the service account for the Load Balancer Controller"
  sensitive = false
}

# ECR
variable "ecr_repository_name" {
  type = string
  description = "The name of the ECR repository"
  sensitive = false
}