resource "helm_release" "lb_controller" {
  name       = local.lb_controller_service_account_name
  namespace  = local.name_space
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "3.5.0"

  set = [
    {
        name = "clusterName"
        value = local.cluster_name
    },
    {
        name = "serviceAccount.name"
        value = local.lb_controller_service_account_name
    },
    {
        name = "serviceAccount.create"
        value = "false"
    },
    {
        name = "region"
        value = var.region
    },
    {
        name = "vpcId"
        value = module.aws.vpc_id
    }
  ]

  depends_on = [kubernetes_service_account_v1.aws-load-balancer-controller, module.aws]
}