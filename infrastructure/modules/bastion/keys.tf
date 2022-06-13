resource "tls_private_key" "servians_tls" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_ssm_parameter" "private_key_pem" {
  name  = "/${var.env_prefix}/ssh/bastion/private_key_pem"
  type  = "SecureString"
  value = tls_private_key.servians_tls.private_key_pem

  tags = merge(var.default_tags, {})
}

resource "aws_ssm_parameter" "public_key_pem" {
  name  = "/${var.env_prefix}/ssh/bastion/public_key_pem"
  type  = "SecureString"
  value = tls_private_key.servians_tls.public_key_pem

  tags = merge(var.default_tags, {})
}

resource "aws_ssm_parameter" "public_key_openssh" {
  name  = "/${var.env_prefix}/ssh/bastion/public_key_openssh"
  type  = "SecureString"
  value = tls_private_key.servians_tls.public_key_openssh

  tags = merge(var.default_tags, {})
}
