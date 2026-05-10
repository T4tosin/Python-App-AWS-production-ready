# environments/prod/terraform.tfvars
# Fill in your values before running

aws_region   = "us-east-1"
project_name = "devops-challenge"
environment  = "prod"

vpc_cidr            = "10.0.0.0/16"
availability_zones  = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]

instance_type = "t3.micro"
ami_id        = "ami-0c02fb55956c7d316" # Amazon Linux 2023 - us-east-1

# Set to your EC2 key pair name (optional, for SSH access)
key_name = ""

# Set by CI/CD pipeline — override with your ECR image URI
# Example: 123456789.dkr.ecr.us-east-1.amazonaws.com/devops-challenge:latest
docker_image = "my-ecr-uri/devops-challenge:latest"
app_version  = "latest"
