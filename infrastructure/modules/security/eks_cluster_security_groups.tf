########################################################################
#Cluster Security Group
########################################################################

resource "aws_security_group" "eks_cluster" {
  name   = "${var.env_prefix}-eks-cluster-sg"
  vpc_id = var.vpc_id

  tags = merge(var.default_tags, {
    Name = "${var.env_prefix}-eks-cluster-sg"
  })

  description = "Auto assigned by code."
}

resource "aws_security_group_rule" "eks_cluster_ingress_443" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id

  security_group_id = aws_security_group.eks_cluster.id

  description = "Auto assigned by code."
}

########################################################################
# Workernode Security Groups
########################################################################

resource "aws_security_group" "eks_nodes" {
  name   = "${var.env_prefix}-eks-nodes-sg"
  vpc_id = var.vpc_id

  tags = merge(var.default_tags, {
    Name = "${var.env_prefix}-eks-nodes-sg"
  })

  description = "Auto assigned by code."
}

resource "aws_security_group_rule" "eks_nodes_ingress_22" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id

  security_group_id = aws_security_group.eks_nodes.id

  description = "Auto assigned by code."
}

resource "aws_security_group_rule" "eks_nodes_ingress_30080" {
  type                     = "ingress"
  from_port                = 30080
  to_port                  = 30080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.front.id

  security_group_id = aws_security_group.eks_nodes.id

  description = "Auto assigned by code."
}

resource "aws_security_group_rule" "eks_nodes_ingress_30443" {
  type                     = "ingress"
  from_port                = 30443
  to_port                  = 30443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.front.id

  security_group_id = aws_security_group.eks_nodes.id

  description = "Auto assigned by code."
}