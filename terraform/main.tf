terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state — update bucket name before use
  backend "s3" {
    bucket         = "devops-challenge-tfstate"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "devops-challenge-tfstate-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# ── VPC ──────────────────────────────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
}

# ── Security Groups ───────────────────────────────────────────────────────────
module "security_groups" {
  source = "./modules/security-groups"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
}

# ── IAM ───────────────────────────────────────────────────────────────────────
module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  environment  = var.environment
}

# ── EC2 ───────────────────────────────────────────────────────────────────────
module "ec2" {
  source = "./modules/ec2"

  project_name          = var.project_name
  environment           = var.environment
  ami_id                = var.ami_id
  instance_type         = var.instance_type
  subnet_id             = module.vpc.public_subnet_ids[0]
  security_group_ids    = [module.security_groups.app_sg_id]
  iam_instance_profile  = module.iam.instance_profile_name
  app_version           = var.app_version
  docker_image          = var.docker_image
  key_name              = var.key_name
}
