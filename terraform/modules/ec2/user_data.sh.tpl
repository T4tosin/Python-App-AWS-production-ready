#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

echo "==> Starting bootstrap for ${project_name} (${environment})"

# ── System updates ────────────────────────────────────────────────────────────
dnf update -y
dnf install -y docker aws-cli jq

# ── Start Docker ──────────────────────────────────────────────────────────────
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

# ── Install CloudWatch Agent ──────────────────────────────────────────────────
dnf install -y amazon-cloudwatch-agent

cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CWAGENT'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/app/app.log",
            "log_group_name": "/${project_name}/${environment}/app",
            "log_stream_name": "{instance_id}/app",
            "retention_in_days": 7
          },
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "/${project_name}/${environment}/bootstrap",
            "log_stream_name": "{instance_id}/bootstrap",
            "retention_in_days": 3
          }
        ]
      }
    }
  },
  "metrics": {
    "append_dimensions": {
      "InstanceId": "$${aws:InstanceId}",
      "Environment": "${environment}"
    },
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"],
        "metrics_collection_interval": 60
      },
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": ["disk_used_percent"],
        "resources": ["/"],
        "metrics_collection_interval": 60
      }
    }
  }
}
CWAGENT

systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

# ── Log directory ─────────────────────────────────────────────────────────────
mkdir -p /var/log/app

# ── Authenticate to ECR (if ECR image) ───────────────────────────────────────
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

if echo "${docker_image}" | grep -q "amazonaws.com"; then
  echo "==> Logging in to ECR"
  aws ecr get-login-password --region "$REGION" | \
    docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
fi

# ── Pull and run the application ──────────────────────────────────────────────
echo "==> Pulling image: ${docker_image}:${app_version}"
docker pull "${docker_image}:${app_version}"

docker run -d \
  --name devops-app \
  --restart unless-stopped \
  -p 5000:5000 \
  -e ENVIRONMENT="${environment}" \
  -e APP_VERSION="${app_version}" \
  -v /var/log/app:/var/log/app \
  "${docker_image}:${app_version}"

echo "==> Bootstrap complete. App running on :5000"
