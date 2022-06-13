resource "aws_eks_fargate_profile" "fargate_profile" {
  cluster_name           = aws_eks_cluster.servians_test_eks.name
  fargate_profile_name   = "coredns"
  pod_execution_role_arn = aws_iam_role.fargate_role.arn
  subnet_ids             = var.vpc_subnet_private_ids

  selector {
    namespace = "kube-system"
    labels = {
      "k8s-app" = "kube-dns"
    }
  }

  depends_on = [
    aws_eks_cluster.servians_test_eks,
    aws_iam_role_policy_attachment.fargate_AmazonEKSFargatePodExecutionRolePolicy
  ]

  tags = merge(var.default_tags, {
    "Name" = "${var.env_prefix}-coredns"
  })
}

resource "aws_eks_fargate_profile" "fargate_profile_load_balancer" {
  cluster_name           = aws_eks_cluster.servians_test_eks.name
  fargate_profile_name   = "aws-load-balancer-controller"
  pod_execution_role_arn = aws_iam_role.fargate_role.arn
  subnet_ids             = var.vpc_subnet_private_ids

  selector {
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name" = "aws-load-balancer-controller"
    }
  }

  selector {
    namespace = "kube-system"
    labels = {
      "app" = "external-dns"
    }
  }

  depends_on = [
    aws_eks_cluster.servians_test_eks,
    aws_iam_role_policy_attachment.fargate_AmazonEKSFargatePodExecutionRolePolicy
  ]

  tags = merge(var.default_tags, {
    "Name" = "${var.env_prefix}-aws-load-balancer-controller"
  })
}

resource "aws_eks_fargate_profile" "fargate_profile_metrics_server" {
  cluster_name           = aws_eks_cluster.servians_test_eks.name
  fargate_profile_name   = "metrics-server"
  pod_execution_role_arn = aws_iam_role.fargate_role.arn
  subnet_ids             = var.vpc_subnet_private_ids

  selector {
    namespace = "kube-system"
    labels = {
      "k8s-app" = "metrics-server"
    }
  }

  depends_on = [
    aws_eks_cluster.servians_test_eks,
    aws_iam_role_policy_attachment.fargate_AmazonEKSFargatePodExecutionRolePolicy
  ]

  tags = merge(var.default_tags, {
    "Name" = "${var.env_prefix}-metrics-server"
  })
}

resource "aws_eks_fargate_profile" "fargate_profile_default" {
  cluster_name           = aws_eks_cluster.servians_test_eks.name
  fargate_profile_name   = "default"
  pod_execution_role_arn = aws_iam_role.fargate_role.arn
  subnet_ids             = var.vpc_subnet_private_ids

  selector {
    namespace = "default"
  }

  depends_on = [
    aws_eks_cluster.servians_test_eks,
    aws_iam_role_policy_attachment.fargate_AmazonEKSFargatePodExecutionRolePolicy
  ]

  tags = merge(var.default_tags, {
    "Name" = "${var.env_prefix}-default"
  })
}

resource "aws_eks_fargate_profile" "fargate_profile_servian" {
  cluster_name           = aws_eks_cluster.servians_test_eks.name
  fargate_profile_name   = "servian"
  pod_execution_role_arn = aws_iam_role.fargate_role.arn
  subnet_ids             = var.vpc_subnet_private_ids

  selector {
    namespace = "servian"
  }

  depends_on = [
    aws_eks_cluster.servians_test_eks,
    aws_iam_role_policy_attachment.fargate_AmazonEKSFargatePodExecutionRolePolicy
  ]

  tags = merge(var.default_tags, {
    "Name" = "${var.env_prefix}-servian"
  })
}


