data "aws_iam_policy_document" "cluster_policy_document" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "eks.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "cluster_role" {
  name               = "${var.env_prefix}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_policy_document.json

  tags = merge(var.default_tags, {})
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

##################################################################################
### fargate IAM
##################################################################################

data "aws_iam_policy_document" "fargate_policy_document" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "eks-fargate-pods.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "fargate_role" {
  name               = "${var.env_prefix}-eks-fargate-role"
  assume_role_policy = data.aws_iam_policy_document.fargate_policy_document.json

  tags = merge(var.default_tags, {})
}

resource "aws_iam_role_policy_attachment" "fargate_AmazonEKSFargatePodExecutionRolePolicy" {
  role       = aws_iam_role.fargate_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

##################################################################################
### Kubernets profiles IAM
##################################################################################

data "aws_iam_policy_document" "masters_policy_document" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = var.eks_arn_user_list_with_masters_role
    }
  }
}

resource "aws_iam_role" "masters_role" {
  name               = "${var.env_prefix}-k8s-masters-role"
  assume_role_policy = data.aws_iam_policy_document.masters_policy_document.json

  tags = merge(var.default_tags, {})
}

data "aws_iam_policy_document" "readonly_policy_document" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = var.eks_arn_user_list_with_readonly_role
    }
  }
}

resource "aws_iam_role" "readonly_role" {
  name               = "${var.env_prefix}-k8s-readonly-role"
  assume_role_policy = data.aws_iam_policy_document.readonly_policy_document.json

  tags = merge(var.default_tags, {})
}

##################################################################################
### Worker nodes IAM
##################################################################################

data "aws_iam_policy_document" "node_policy_document" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node_role" {
  name               = "${var.env_prefix}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_policy_document.json

  tags = merge(var.default_tags, {})
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"

}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_instance_profile" "node_instance_profile" {
  name = "${var.env_prefix}-node-instance-profile"
  role = aws_iam_role.node_role.name
}

resource "aws_iam_policy" "node_csi_ebs_policy" {
  name   = "${var.env_prefix}-eks-node-csi-ebs-policy"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AttachVolume",
        "ec2:CreateSnapshot",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:DeleteSnapshot",
        "ec2:DeleteTags",
        "ec2:DeleteVolume",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeInstances",
        "ec2:DescribeSnapshots",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
        "ec2:DescribeVolumesModifications",
        "ec2:DetachVolume",
        "ec2:ModifyVolume"
      ],
      "Resource": "*"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "node_role_node_csi_ebs_policy" {
  role = aws_iam_role.node_role.name
  policy_arn = aws_iam_policy.node_csi_ebs_policy.arn

  depends_on = [
    aws_iam_role.node_role,
    aws_iam_policy.node_csi_ebs_policy
  ]
}

##################################################################################
### OIDC IAM
##################################################################################

data "tls_certificate" "servians_test_eks" {
  url = aws_eks_cluster.servians_test_eks.identity.0.oidc.0.issuer
}

resource "aws_iam_openid_connect_provider" "servians_test_eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = concat([data.tls_certificate.servians_test_eks.certificates.0.sha1_fingerprint])
  url             = aws_eks_cluster.servians_test_eks.identity.0.oidc.0.issuer
}

##################################################################################
### OIDC External DNS IAM
##################################################################################

data "aws_iam_policy_document" "external_dns_policy_document" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.servians_test_eks.arn]
    }

    condition {
      test = "StringEquals"
      values = [
        "system:serviceaccount:kube-system:external-dns"
      ]
      variable = "${replace(aws_iam_openid_connect_provider.servians_test_eks.url, "https://", "")}:sub"
    }

    condition {
      test = "StringEquals"
      values = [
        "sts.amazonaws.com"
      ]
      variable = "${replace(aws_iam_openid_connect_provider.servians_test_eks.url, "https://", "")}:aud"
    }
  }
}

resource "aws_iam_role" "external_dns_role" {
  name               = "${var.env_prefix}-eks-external-dns-role"
  assume_role_policy = data.aws_iam_policy_document.external_dns_policy_document.json

  tags = merge(var.default_tags, {})

  depends_on = [
    aws_iam_openid_connect_provider.servians_test_eks
  ]
}

resource "aws_iam_policy" "external_dns_policy" {
  name   = "${var.env_prefix}-eks-external-dns-policy"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": [
        "arn:aws:route53:::hostedzone/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "external_dns_external_dns_policy" {
  role       = aws_iam_role.external_dns_role.name
  policy_arn = aws_iam_policy.external_dns_policy.arn

  depends_on = [
    aws_iam_role.external_dns_role,
    aws_iam_policy.external_dns_policy
  ]
}

##################################################################################
### OIDC ELB Controller IAM
##################################################################################

data "aws_iam_policy_document" "lb_controller_policy_document" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.servians_test_eks.arn]
    }

    condition {
      test = "StringEquals"
      values = [
        "system:serviceaccount:kube-system:aws-load-balancer-controller"
      ]
      variable = "${replace(aws_iam_openid_connect_provider.servians_test_eks.url, "https://", "")}:sub"
    }

    condition {
      test = "StringEquals"
      values = [
        "sts.amazonaws.com"
      ]
      variable = "${replace(aws_iam_openid_connect_provider.servians_test_eks.url, "https://", "")}:aud"
    }
  }
}

resource "aws_iam_role" "lb_controller_role" {
  name               = "${var.env_prefix}-eks-lb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.lb_controller_policy_document.json

  tags = merge(var.default_tags, {})

  depends_on = [
    aws_iam_openid_connect_provider.servians_test_eks
  ]
}

resource "aws_iam_policy" "lb_controller_policy" {
  name   = "${var.env_prefix}-eks-lb-controller-policy"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateServiceLinkedRole",
        "ec2:DescribeAccountAttributes",
        "ec2:DescribeAddresses",
        "ec2:DescribeInternetGateways",
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeInstances",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeTags",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeLoadBalancerAttributes",
        "elasticloadbalancing:DescribeListeners",
        "elasticloadbalancing:DescribeListenerCertificates",
        "elasticloadbalancing:DescribeSSLPolicies",
        "elasticloadbalancing:DescribeRules",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetGroupAttributes",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:DescribeTags"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cognito-idp:DescribeUserPoolClient",
        "acm:ListCertificates",
        "acm:DescribeCertificate",
        "iam:ListServerCertificates",
        "iam:GetServerCertificate",
        "waf-regional:GetWebACL",
        "waf-regional:GetWebACLForResource",
        "waf-regional:AssociateWebACL",
        "waf-regional:DisassociateWebACL",
        "wafv2:GetWebACL",
        "wafv2:GetWebACLForResource",
        "wafv2:AssociateWebACL",
        "wafv2:DisassociateWebACL",
        "shield:GetSubscriptionState",
        "shield:DescribeProtection",
        "shield:CreateProtection",
        "shield:DeleteProtection"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateSecurityGroup"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateTags"
      ],
      "Resource": "arn:aws:ec2:*:*:security-group/*",
      "Condition": {
        "StringEquals": {
          "ec2:CreateAction": "CreateSecurityGroup"
        },
        "Null": {
          "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateTags",
        "ec2:DeleteTags"
      ],
      "Resource": "arn:aws:ec2:*:*:security-group/*",
      "Condition": {
        "Null": {
          "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
          "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:DeleteSecurityGroup"
      ],
      "Resource": "*",
      "Condition": {
        "Null": {
          "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:CreateTargetGroup"
      ],
      "Resource": "*",
      "Condition": {
        "Null": {
          "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:CreateListener",
        "elasticloadbalancing:DeleteListener",
        "elasticloadbalancing:CreateRule",
        "elasticloadbalancing:DeleteRule"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:RemoveTags"
      ],
      "Resource": [
        "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
        "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
        "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
      ],
      "Condition": {
        "Null": {
          "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
          "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:SetIpAddressType",
        "elasticloadbalancing:SetSecurityGroups",
        "elasticloadbalancing:SetSubnets",
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:ModifyTargetGroup",
        "elasticloadbalancing:ModifyTargetGroupAttributes",
        "elasticloadbalancing:DeleteTargetGroup"
      ],
      "Resource": "*",
      "Condition": {
        "Null": {
          "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:DeregisterTargets"
      ],
      "Resource": "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:SetWebAcl",
        "elasticloadbalancing:ModifyListener",
        "elasticloadbalancing:AddListenerCertificates",
        "elasticloadbalancing:RemoveListenerCertificates",
        "elasticloadbalancing:ModifyRule"
      ],
      "Resource": "*"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "lb_controller_lb_controller_policy" {
  role       = aws_iam_role.lb_controller_role.name
  policy_arn = aws_iam_policy.lb_controller_policy.arn

  depends_on = [
    aws_iam_role.lb_controller_role,
    aws_iam_policy.lb_controller_policy
  ]
}

