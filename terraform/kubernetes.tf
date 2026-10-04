resource "kubernetes_service_account_v1" "aws-load-balancer-controller" {
  metadata {
    name      = local.lb_controller_service_account_name
    namespace = local.name_space
  }
}