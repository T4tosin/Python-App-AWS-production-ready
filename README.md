# DevOps Challenge — Production-Ready Python App Deployment

A lightweight Python Flask microservice deployed to AWS EC2 using a fully automated CI/CD pipeline built with GitHub Actions, infrastructure provisioned with Terraform, containerised with Docker, and monitored via AWS CloudWatch.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Quick Start (Local)](#quick-start-local)
- [Deployment Steps (AWS)](#deployment-steps-aws)
- [CI/CD Pipeline](#cicd-pipeline)
- [Monitoring & Logging](#monitoring--logging)
- [Design Decisions](#design-decisions)
- [Assumptions](#assumptions)
- [Limitations & Future Improvements](#limitations--future-improvements)

---

## Architecture Overview

```
Developer (git push)
        │
        ▼
GitHub Actions Pipeline
  ├── 1. Build & Test  ──── Python unit tests (pytest)
  ├── 2. Docker Build  ──── Multi-stage Docker build
  ├── 3. Push to ECR   ──── Tagged with git SHA + latest
  └── 4. Terraform     ──── Plan → Apply (deploys to EC2)
                │
                ▼
        AWS Cloud (us-east-1)
        └── VPC (10.0.0.0/16)
            └── Public Subnet
                ├── EC2 Instance (t3.micro, Amazon Linux 2023)
                │   ├── Docker container (Flask app :5000)
                │   └── CloudWatch Agent (metrics + logs)
                ├── Security Group (ports 80, 5000, 22)
                └── IAM Role (CloudWatch + ECR + SSM)
                        │
                        ▼
                AWS CloudWatch
                ├── Log Groups (app + bootstrap logs)
                ├── Metric Alarms (CPU, memory, disk)
                ├── Dashboard (real-time view)
                └── SNS Topic → Email alerts
```

**Local development** also ships logs via Filebeat into an ELK stack (Elasticsearch + Kibana) running in Docker Compose.

---

## Repository Structure

```
devops-challenge/
├── app/
│   ├── main.py              # Flask application (/, /health, /metrics)
│   ├── test_main.py         # pytest unit tests
│   ├── requirements.txt     # Python dependencies
│   ├── Dockerfile           # Multi-stage Docker build
│   └── .dockerignore
│
├── terraform/
│   ├── main.tf              # Root module — wires sub-modules together
│   ├── variables.tf         # All input variables
│   ├── outputs.tf           # Deployment outputs (IP, URL, SSH)
│   ├── environments/
│   │   └── prod/
│   │       └── terraform.tfvars   # Prod variable values
│   └── modules/
│       ├── vpc/             # VPC, subnets, IGW, route tables
│       ├── security-groups/ # App security group (ports 80/5000/22)
│       ├── iam/             # EC2 instance role + instance profile
│       └── ec2/             # EC2 instance, Elastic IP, user_data bootstrap
│
├── .github/
│   └── workflows/
│       └── ci-cd.yml        # GitHub Actions pipeline (4 jobs)
│
├── monitoring/
│   ├── cloudwatch.tf        # CloudWatch log groups, alarms, dashboard, SNS
│   └── filebeat.yml         # Filebeat config for local ELK stack
│
├── ci-cd/
│   └── bootstrap-tfstate.sh # One-time S3 + DynamoDB backend setup script
│
├── docker-compose.yml       # Local dev: app + ELK stack
├── Makefile                 # Developer shortcuts
└── README.md
```

---

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Docker | 24+ | Container build & run |
| Python | 3.12+ | Local test runs |
| Terraform | 1.6+ | Infrastructure provisioning |
| AWS CLI | 2.x | ECR login, bootstrap |
| Make | any | Developer shortcuts |

**AWS Permissions required** (attach to your IAM user/role):
- `AmazonEC2FullAccess`
- `AmazonVPCFullAccess`
- `AmazonECRFullAccess`
- `IAMFullAccess`
- `CloudWatchFullAccess`
- `AmazonDynamoDBFullAccess`
- `AmazonS3FullAccess`

---

## Quick Start (Local)

```bash
# 1. Clone the repo
git clone https://github.com/t4tosin/devops-challenge.git
cd devops-challenge

# 2. Run app only (no ELK)
make run-app

# App is live at:
#   http://localhost:5000/
#   http://localhost:5000/health
#   http://localhost:5000/metrics

# 3. Run full stack with ELK monitoring
make run
# Kibana: http://localhost:5601

# 4. Run tests
make test-local

# 5. Tear down
make stop
```

---

## Deployment Steps (AWS)

### Step 1 — Configure AWS credentials

```bash
aws configure
# Enter: AWS Access Key ID, Secret Access Key, region (us-east-1), output (json)
```

### Step 2 — Bootstrap Terraform remote state (run once)

```bash
export AWS_REGION=us-east-1
export TF_STATE_BUCKET=devops-challenge-tfstate   # must be globally unique
bash ci-cd/bootstrap-tfstate.sh
```

This creates:
- S3 bucket (versioned, encrypted, private) for Terraform state
- DynamoDB table for state locking

### Step 3 — Update variables

Edit `terraform/environments/prod/terraform.tfvars`:

```hcl
docker_image = "<your-account-id>.dkr.ecr.us-east-1.amazonaws.com/devops-challenge:latest"
# Optionally set key_name = "your-ec2-keypair" for SSH access
```

### Step 4 — Add GitHub Actions secrets

In your GitHub repo → Settings → Secrets → Actions, add:

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key |

### Step 5 — Push to main (triggers pipeline)

```bash
git add .
git commit -m "feat: initial deployment"
git push origin main
```

The pipeline will:
1. Run tests
2. Build and push Docker image to ECR
3. Run `terraform plan`
4. Run `terraform apply` — provisions VPC, EC2, security groups, IAM, Elastic IP

### Step 6 — Access the application

After the pipeline completes, get the URL from Terraform outputs:

```bash
cd terraform && terraform output
# app_url            = "http://<public-ip>:5000"
# health_check_url   = "http://<public-ip>:5000/health"
```

Or check the GitHub Actions summary — the deploy job writes the URL there.

### Manual deploy (without CI/CD)

```bash
make tf-init
make tf-plan
make tf-apply
make tf-output
```

---

## CI/CD Pipeline

The pipeline has four jobs, each requiring the previous to succeed:

```
build-and-test  →  push-to-ecr  →  terraform-plan  →  deploy
```

| Job | Trigger | What it does |
|-----|---------|--------------|
| `build-and-test` | All pushes & PRs | Installs deps, runs pytest, validates Docker build |
| `push-to-ecr` | Push to `main` only | Logs into ECR, builds + pushes image tagged with git SHA |
| `terraform-plan` | Push to `main` only | Runs `terraform plan`, uploads plan artifact |
| `deploy` | Push to `main` only | Runs `terraform apply` with the saved plan |

**Key features:**
- Docker layer caching via GitHub Actions cache (faster builds)
- ECR repository auto-created if missing
- `terraform plan` and `apply` use the same saved plan file (no drift)
- Deploy job is a GitHub `environment: production` — can require manual approval
- Job summary shows app URL and health URL after deploy

---

## Monitoring & Logging

### AWS CloudWatch (production)

The CloudWatch Agent runs on the EC2 instance and ships:

| Data | CloudWatch destination |
|------|----------------------|
| App logs (`/var/log/app/app.log`) | Log group: `/<project>/<env>/app` |
| Bootstrap logs | Log group: `/<project>/<env>/bootstrap` |
| CPU usage | Namespace: `CWAgent` |
| Memory used % | Namespace: `CWAgent` |
| Disk used % | Namespace: `CWAgent` |

**Alarms** (defined in `monitoring/cloudwatch.tf`):
- CPU > 80% for 4 minutes → SNS alert
- Memory > 85% for 4 minutes → SNS alert
- Disk > 90% → SNS alert

**Dashboard**: Auto-created at `CloudWatch → Dashboards → devops-challenge-prod`

To receive email alerts, set `alert_email` in `monitoring/cloudwatch.tf`.

### ELK Stack (local development)

```bash
make run          # starts app + Elasticsearch + Kibana + Filebeat
open http://localhost:5601   # Kibana
```

Filebeat ships:
- App log files from `/var/log/app/`
- Docker container stdout/stderr

In Kibana: create an index pattern `devops-challenge-*` to explore logs.

---

## Design Decisions

**EC2 over ECS/EKS**  
EC2 was chosen for its simplicity and lower operational overhead for a single-service deployment. ECS would add complexity (task definitions, cluster management) without meaningful benefit at this scale. EKS would be overkill for a single microservice.

**Multi-stage Docker build**  
The Dockerfile uses a builder stage to install dependencies and a separate runtime stage for the final image. This keeps the production image small and free of build tools. The app also runs as a non-root user for improved security.

**Modular Terraform**  
Infrastructure is split into four focused modules (vpc, security-groups, iam, ec2) rather than a monolithic config. Each module has a single responsibility and can be reused across environments. Remote state is stored in S3 with DynamoDB locking to prevent concurrent apply conflicts.

**Elastic IP**  
An Elastic IP is attached to the EC2 instance so the public IP remains stable across instance stops/restarts, making the endpoint predictable for DNS or direct access.

**Gunicorn as the WSGI server**  
Flask's built-in server is not suitable for production. Gunicorn with 2 workers and 4 threads provides concurrency without requiring a reverse proxy for this scale.

**CloudWatch + ELK**  
CloudWatch handles production monitoring (metrics, alarms, log aggregation) natively with no additional infrastructure. ELK is offered as a local alternative for richer log search during development, matching the "equivalent solution" requirement.

**GitHub Actions over Jenkins**  
GitHub Actions requires no server to maintain and integrates natively with the repository. The pipeline is defined in a single YAML file and is easy to audit. Jenkins would require provisioning and maintaining a dedicated server.

---

## Assumptions

- The AWS account has no existing VPC/resource conflicts with the `10.0.0.0/16` CIDR range.
- The deploying IAM user has sufficient permissions (listed in Prerequisites).
- The S3 bucket name for Terraform state is globally unique — update `TF_STATE_BUCKET` if the default is taken.
- The AMI ID (`ami-0c02fb55956c7d316`) is Amazon Linux 2023 in `us-east-1`. Update this if deploying to a different region.
- Port 5000 is directly exposed. In a production hardening pass, an ALB + HTTPS termination would sit in front.

---

## Limitations & Future Improvements

| Area | Current | Improvement |
|------|---------|-------------|
| TLS/HTTPS | None — HTTP only on :5000 | Add Application Load Balancer + ACM certificate |
| Scaling | Single EC2 instance | Auto Scaling Group behind an ALB |
| Database | None | Add RDS (Postgres) with private subnet |
| Secrets | Environment variables | AWS Secrets Manager or Parameter Store |
| SSH access | Port 22 open to 0.0.0.0/0 | Restrict to VPN CIDR or use SSM Session Manager only |
| Rollback | Re-run pipeline with old SHA | Blue/green deployment or CodeDeploy |
| Multi-environment | Prod only | Add `staging` workspace with separate tfvars |
| Container orchestration | Docker on EC2 | Migrate to ECS Fargate for managed container runtime |
| Log retention | 7 days (CloudWatch) | Tune to compliance requirement |
