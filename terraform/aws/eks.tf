module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = "1.35"

  enable_irsa          = false
  create_cloudwatch_log_group = false
  #  This is default for k8s version 1.35 and above
  # https://aws.amazon.com/about-aws/whats-new/2025/03/amazon-eks-envelope-encrypts-kubernetes-api-data-default/
  create_kms_key = false
  encryption_config = null

  # EKS Addons
  addons = {
    coredns = {}
    kube-proxy = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    vpc-cni = {
      before_compute = true
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  endpoint_public_access = true
  endpoint_public_access_cidrs = var.admin_cidrs

  eks_managed_node_groups = {
    ng-1 = {
      # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
      instance_types = ["t3.medium"]
      ami_type       = "AL2023_x86_64_STANDARD"

      min_size = 1
      max_size = 2
      desired_size = 1
    }
  }

  access_entries = {
    terraform_admin = {
      principal_arn = var.provider_assume_role_arn

      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  tags = var.tags
}

resource "aws_eks_pod_identity_association" "lb_controller" {
  cluster_name    = var.cluster_name
  namespace       = var.name_space
  service_account = var.lb_controller_service_account_name
  role_arn        = aws_iam_role.eks_pod_identity_lb_controller_role.arn
}