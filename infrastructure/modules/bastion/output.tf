output "name" {
  value = "${var.env_prefix}-bastion"
}

output "private_key" {
  value = aws_ssm_parameter.private_key_pem.value
}
