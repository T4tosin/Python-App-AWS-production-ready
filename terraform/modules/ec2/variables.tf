variable "project_name" { type = string }
variable "environment" { type = string }
variable "ami_id" { type = string }
variable "instance_type" { type = string }
variable "subnet_id" { type = string }
variable "security_group_ids" { type = list(string) }
variable "iam_instance_profile" { type = string }
variable "app_version" { type = string }
variable "docker_image" { type = string }
variable "key_name" { type = string; default = "" }
