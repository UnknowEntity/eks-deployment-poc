# Policy principal for the Load Balancer Controller IAM role
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

data "http" "aws_lb_controller_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
}

# Policy permission for the Load Balancer Controller IAM role
resource "aws_iam_policy" "aws_lb_controller_iam_policy" {
  name        = "AmazonEKSLoadBalancerControllerPolicy"
  description = "The IAM policy for the Load Balancer Controller"
  
  # data.http.<name>.response_body contains the raw string contents of the JSON file
  policy      = data.http.aws_lb_controller_iam_policy.response_body
}

resource "aws_iam_role" "eks_pod_identity_lb_controller_role" {
  name               = "eks-pod-identity-lb-controller"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_pod_identity_lb_controller" {
  policy_arn = aws_iam_policy.aws_lb_controller_iam_policy.arn
  role       = aws_iam_role.eks_pod_identity_lb_controller_role.name
}