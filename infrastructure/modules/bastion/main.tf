resource "aws_key_pair" "key_pair_bastion" {
  key_name   = "${var.env_prefix}-bastion"
  public_key = aws_ssm_parameter.public_key_openssh.value
}

data "aws_availability_zones" "available" {}
