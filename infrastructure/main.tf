###########################################################################################
# All the provider versions for modules and configurations.
###########################################################################################

terraform {
  backend "s3" {}

required_providers {
    external = {
      source  = "external"
      version = "~> 2.0"
    }
  

    aws= {
      source  = "aws"
      version = "~> 3.0"
    }
  }
}

###########################################################################################
# Module core contains code for VPC, Subnets, Route tables, NAT gateway, IAM for flow logs
###########################################################################################
module "core" {
  source = "./modules/core"

  env_prefix   = var.env_prefix
  default_tags = var.default_tags
  vpc_cidr    = var.vpc_cidr
  vpc_az_size = var.vpc_az_size
  nat_gateway_size = var.nat_gateway_size
  vpc_subnet_public_cidr  = var.vpc_subnet_public_cidr
  vpc_subnet_private_cidr = var.vpc_subnet_private_cidr
  vpc_subnet_database_cidr = var.vpc_subnet_database_cidr
}

###########################################################################################
# Module security contains security groups for Bastion Host, EKS cluster, RDS, ALB's
###########################################################################################

module "security" {
  source = "./modules/security"

  env_prefix   = var.env_prefix
  default_tags = var.default_tags

  vpc_id                  = module.core.vpc_id
  vpc_cidr                = var.vpc_cidr
  vpc_subnet_private_cidr = var.vpc_subnet_private_cidr

  bastion_allowed_port  = var.bastion_allowed_port
  bastion_allowed_cidrs = var.bastion_allowed_cidrs
}

###########################################################################################
# Module database contains RDS configurations
###########################################################################################

module "database" {
  source = "./modules/database"

  env_prefix   = var.env_prefix
  default_tags = var.default_tags
  vpc_id                 = module.core.vpc_id
  vpc_az_size            = var.vpc_az_size
  vpc_subnet_database_ids = module.core.vpc_subnet_database_ids
  database_instance_class = var.database_instance_class
  security_group_database_id = module.security.security_group_database_id
}

#################################################################################################
# Module Bastion contains configurations of bastion host
#################################################################################################

module "bastion" {
  source = "./modules/bastion"

  env_prefix   = var.env_prefix
  default_tags = var.default_tags
  vpc_subnet_public_ids     = module.core.vpc_subnet_public_ids
  security_group_bastion_id = module.security.security_group_bastion_id
  bastion_allowed_port = var.bastion_allowed_port
}

#################################################################################################
# Module EKS contains configuration for EKS cluster
#################################################################################################

module "eks" {
  source = "./modules/eks"

  env_prefix   = var.env_prefix
  default_tags = var.default_tags
  eks_version = var.eks_version
  vpc_subnet_public_ids  = module.core.vpc_subnet_public_ids
  vpc_subnet_private_ids = module.core.vpc_subnet_private_ids
  security_group_bastion_id     = module.security.security_group_bastion_id
  security_group_eks_cluster_id = module.security.security_group_eks_cluster_id
  security_group_front_id       = module.security.security_group_front_id
  eks_arn_user_list_with_masters_role  = var.eks_arn_user_list_with_masters_role
  eks_arn_user_list_with_readonly_role = var.eks_arn_user_list_with_readonly_role
}

#################################################################################################
# Genarate self sign certificate for application
#################################################################################################

module certificate {
  source = "./modules/certificate"

  cert_dns_name = var.cert_dns_name
  cert_org_name = var.cert_org_name
}

##################################################################################################################################
#ALB controller, External DNS configurations, Servian app Deployment and Package installations
#############################################################################################################
module "configurations" {
  source = "./modules/configurations"

  env_prefix   = var.env_prefix
  default_tags = var.default_tags

  bastion_name         = module.bastion.name
  bastion_private_key  = module.bastion.private_key
  bastion_allowed_port = var.bastion_allowed_port

  domain_name = var.domain_name

  vpc_id                              = module.core.vpc_id
  eks_cluster_name                    = module.eks.eks_cluster_name
  eks_fargate_profile_id              = module.eks.eks_fargate_profile_id
  eks_node_role_arn                   = module.eks.eks_node_role_arn
  eks_fargate_role_arn                = module.eks.eks_fargate_role_arn
  eks_external_dns_role_arn           = module.eks.eks_external_dns_role_arn
  eks_lb_controller_role_arn          = module.eks.eks_lb_controller_role_arn
  eks_k8s_masters_role_arn            = module.eks.eks_k8s_masters_role_arn
  eks_k8s_readonly_role_arn           = module.eks.eks_k8s_readonly_role_arn
  eks_arn_user_list_with_masters_user = var.eks_arn_user_list_with_masters_user

  eks_alb_ing_ssl_cert_arn            = module.certificate.alb_ing_ssl_cert_arn
  app_backend_db_host                 = module.database.rds_address
  app_backend_db_port                 = module.database.rds_port
  app_backend_db_user                 = base64encode(module.database.rds_username_root_value)
  app_backend_db_password             = base64encode(module.database.rds_password_root_value)
}

