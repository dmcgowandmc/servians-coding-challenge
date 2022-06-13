variable "env_prefix" {
}

variable "default_tags" {
  type = map(string)
}

variable "vpc_id" {
}

variable "vpc_az_size" {
}

variable "vpc_subnet_database_ids" {
  type = list(string)
}

variable "security_group_database_id" {
}

variable "database_instance_class" {
}
