env_prefix = "preprod-servian"

default_tags = {
  "Client" = "servian",
  "Project" = "servian-demo",
  "Environment" = "preprod"
}

domain_name     = "nonprod-test.servian.cloud"
subdomain_names = ["serviantc-test"]
certificate_arn = ""

# EKS
eks_version = "1.21"
# Allows you to give administration permissions to the EKS
eks_arn_user_list_with_masters_user = [
  "arn:aws:iam::226007644731:user/sumudumari"
]

eks_arn_user_list_with_masters_role = [
 "arn:aws:iam::226007644731:user/sumudumari"
]

eks_arn_user_list_with_readonly_role = [
 "arn:aws:iam::226007644731:user/sumudumari"
]

# core
vpc_cidr                = "10.0.0.0/20"
vpc_az_size             = "3"
vpc_subnet_public_cidr  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
vpc_subnet_private_cidr = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
vpc_subnet_database_cidr = ["10.0.7.0/24", "10.0.8.0/24", "10.0.9.0/24"]

nat_gateway_size = "1"

# Database (RDS)
database_instance_class = "db.t4g.large"

# BASTION ALLOWED
bastion_allowed_port = "22"
bastion_allowed_cidrs = ["175.159.55.79/32"]

# ACM Certificate related
cert_dns_name = "*.ap-southeast-1.elb.amazonaws.com"
cert_org_name = "servians"