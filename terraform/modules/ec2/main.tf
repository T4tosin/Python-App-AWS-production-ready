resource "aws_instance" "app" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile   = var.iam_instance_profile
  key_name               = var.key_name != "" ? var.key_name : null

  # Root volume
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }

  # Bootstrap: install Docker, pull image, start app + CloudWatch agent
  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    docker_image = var.docker_image
    app_version  = var.app_version
    environment  = var.environment
    project_name = var.project_name
  }))

  tags = {
    Name = "${var.project_name}-${var.environment}-app"
  }
}

# Elastic IP for stable public address
resource "aws_eip" "app" {
  instance = aws_instance.app.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-eip"
  }
}
