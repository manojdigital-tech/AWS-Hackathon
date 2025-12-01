
#!/usr/bin/env bash
set -euo pipefail

# Usage: ./bootstrap-structure.sh <root_folder>
ROOT="${1:-clinic-microservices-starter}"

echo "Creating repo structure under: ${ROOT}"

# --- Directory tree ---
mkdir -p "${ROOT}"/app/patient-service/src
mkdir -p "${ROOT}"/app/appointment-service/src
mkdir -p "${ROOT}"/app
mkdir -p "${ROOT}"/terraform/env
mkdir -p "${ROOT}"/terraform/modules/vpc
mkdir -p "${ROOT}"/terraform/modules/iam
mkdir -p "${ROOT}"/terraform/modules/ecr
mkdir -p "${ROOT}"/terraform/modules/ecs
mkdir -p "${ROOT}"/terraform/modules/observability
mkdir -p "${ROOT}"/.github/workflows

# --- Top-level README ---
cat > "${ROOT}/README.md" <<'EOF'
# Clinic Microservices Starter

Dockerized Node.js microservices deployed on AWS ECS Fargate via Terraform,
with remote state (S3 + DynamoDB), multi-environment workspaces, and GitHub Actions CI/CD.

See `terraform/env/*.tfvars` for environment-specific values.
EOF

# --- Docker compose ---
cat > "${ROOT}/app/docker-compose.yml" <<'EOF'
version: "3.9"
services:
  patient-service:
    build: ./patient-service
    ports: ["3001:3001"]
    environment:
      - NODE_ENV=development
  appointment-service:
    build: ./appointment-service
    ports: ["3002:3002"]
    environment:
      - NODE_ENV=development
networks:
  default:
    name: clinic-net
EOF

# --- Patient service placeholders ---
cat > "${ROOT}/app/patient-service/Dockerfile" <<'EOF'
# syntax=docker/dockerfile:1
FROM node:18-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:18-alpine AS runner
ENV NODE_ENV=production
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
EXPOSE 3001
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:3001/health || exit 1
CMD ["node", "src/index.js"]
EOF

cat > "${ROOT}/app/patient-service/.dockerignore" <<'EOF'
node_modules
npm-debug.log
Dockerfile
.git
.gitignore
.env
EOF

cat > "${ROOT}/app/patient-service/package.json" <<'EOF'
{
  "name": "patient-service",
  "version": "1.0.0",
  "type": "module",
  "main": "src/index.js",
  "dependencies": { "express": "^4.19.2" }
}
EOF

cat > "${ROOT}/app/patient-service/src/index.js" <<'EOF'
import express from "express";
const app = express();
const PORT = process.env.PORT || 3001;

app.get("/health", (_, res) => res.status(200).send("OK"));
app.get("/patient", (_, res) => res.json({ service: "patient", ok: true }));

app.listen(PORT, () => console.log(`Patient service on ${PORT}`));
EOF

# --- Appointment service placeholders ---
cat > "${ROOT}/app/appointment-service/Dockerfile" <<'EOF'
# syntax=docker/dockerfile:1
FROM node:18-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:18-alpine AS runner
ENV NODE_ENV=production
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
EXPOSE 3002
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:3002/health || exit 1
CMD ["node", "src/index.js"]
EOF

cat > "${ROOT}/app/appointment-service/.dockerignore" <<'EOF'
node_modules
npm-debug.log
Dockerfile
.git
.gitignore
.env
EOF

cat > "${ROOT}/app/appointment-service/package.json" <<'EOF'
{
  "name": "appointment-service",
  "version": "1.0.0",
  "type": "module",
  "main": "src/index.js",
  "dependencies": { "express": "^4.19.2" }
}
EOF

cat > "${ROOT}/app/appointment-service/src/index.js" <<'EOF'
import express from "express";
const app = express();
const PORT = process.env.PORT || 3002;

app.get("/health", (_, res) => res.status(200).send("OK"));
app.get("/appointment", (_, res) => res.json({ service: "appointment", ok: true }));

app.listen(PORT, () => console.log(`Appointment service on ${PORT}`));
EOF

# --- Terraform core files ---
cat > "${ROOT}/terraform/versions.tf" <<'EOF'
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }
}
EOF

cat > "${ROOT}/terraform/providers.tf" <<'EOF'
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Env       = terraform.workspace
    }
  }
}
EOF

cat > "${ROOT}/terraform/backend.tf" <<'EOF'
terraform {
  backend "s3" {
    bucket         = var.tfstate_bucket_name
    key            = "iac/${terraform.workspace}.tfstate"
    region         = var.aws_region
    dynamodb_table = var.tfstate_lock_table
    encrypt        = true
  }
}
EOF

cat > "${ROOT}/terraform/variables.tf" <<'EOF'
variable "aws_region"          { type = string, default = "ap-southeast-2" }
variable "azs"                 { type = list(string), default = ["ap-southeast-2a", "ap-southeast-2b"] }
variable "tfstate_bucket_name" { type = string }
variable "tfstate_lock_table"  { type = string }
variable "project_name"        { type = string, default = "clinic-microservices" }
variable "app_domain"          { type = string, default = null }
EOF

cat > "${ROOT}/terraform/main.tf" <<'EOF'
module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
  azs          = var.azs
}

module "iam" {
  source       = "./modules/iam"
  project_name = var.project_name
}

module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
}

module "ecs" {
  source                      = "./modules/ecs"
  project_name                = var.project_name
  vpc_id                      = module.vpc.vpc_id
  public_subnet_ids           = module.vpc.public_subnet_ids
  private_subnet_ids          = module.vpc.private_subnet_ids
  task_exec_role_arn          = module.iam.task_exec_role_arn
  task_role_arn               = module.iam.task_role_arn
  ecr_patient_repo_url        = module.ecr.patient_repo_url
  ecr_appointment_repo_url    = module.ecr.appointment_repo_url
  aws_region                  = var.aws_region
}

module "observability" {
  source           = "./modules/observability"
  project_name     = var.project_name
  ecs_cluster_name = module.ecs.cluster_name
  alb_arn          = module.ecs.alb_arn
  aws_region       = var.aws_region
}
EOF

cat > "${ROOT}/terraform/outputs.tf" <<'EOF'
output "alb_dns_name"         { value = module.ecs.alb_dns_name }
output "ecr_patient_repo"     { value = module.ecr.patient_repo_url }
output "ecr_appointment_repo" { value = module.ecr.appointment_repo_url }
EOF

# --- Env tfvars ---
cat > "${ROOT}/terraform/env/dev.tfvars" <<'EOF'
tfstate_bucket_name = "tfstate-clinic-microservices"
tfstate_lock_table  = "tfstate-locks"
project_name        = "clinic-microservices-dev"
EOF

cat > "${ROOT}/terraform/env/staging.tfvars" <<'EOF'
tfstate_bucket_name = "tfstate-clinic-microservices"
tfstate_lock_table  = "tfstate-locks"
project_name        = "clinic-microservices-staging"
EOF

cat > "${ROOT}/terraform/env/prod.tfvars" <<'EOF'
tfstate_bucket_name = "tfstate-clinic-microservices"
tfstate_lock_table  = "tfstate-locks"
project_name        = "clinic-microservices-prod"
EOF

# --- Terraform module placeholders (minimal, working) ---
cat > "${ROOT}/terraform/modules/vpc/variables.tf" <<'EOF'
variable "project_name" { type = string }
variable "azs"          { type = list(string) }
EOF

cat > "${ROOT}/terraform/modules/vpc/main.tf" <<'EOF'
resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "${var.project_name}-vpc" }
}

resource "aws_internet_gateway" "igw" { vpc_id = aws_vpc.this.id }

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 4, count.index)
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true
  tags = { Name = "${var.project_name}-public-${count.index}" }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 4, count.index + 8)
  availability_zone = var.azs[count.index]
  tags = { Name = "${var.project_name}-private-${count.index}" }
}

resource "aws_eip" "nat" { count = 2, domain = "vpc" }

resource "aws_nat_gateway" "nat" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags = { Name = "${var.project_name}-nat-${count.index}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route { cidr_block = "0.0.0.0/0", gateway_id = aws_internet_gateway.igw.id }
}
resource "aws_route_table_association" "public_assoc" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  route { cidr_block = "0.0.0.0/0", nat_gateway_id = aws_nat_gateway.nat[0].id }
}
resource "aws_route_table_association" "private_assoc" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
EOF

cat > "${ROOT}/terraform/modules/vpc/outputs.tf" <<'EOF'
output "vpc_id"             { value = aws_vpc.this.id }
output "public_subnet_ids"  { value = [for s in aws_subnet.public : s.id] }
output "private_subnet_ids" { value = [for s in aws_subnet.private : s.id] }
EOF

cat > "${ROOT}/terraform/modules/iam/variables.tf" <<'EOF'
variable "project_name" { type = string }
EOF

cat > "${ROOT}/terraform/modules/iam/main.tf" <<'EOF'
data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service", identifiers = ["ecs-tasks.amazonaws.com"] }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${var.project_name}-ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

resource "aws_iam_role_policy_attachment" "ecs_exec_attachment" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name               = "${var.project_name}-ecsTaskRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

output "task_exec_role_arn" { value = aws_iam_role.ecs_task_execution.arn }
output "task_role_arn"      { value = aws_iam_role.ecs_task_role.arn }
EOF

cat > "${ROOT}/terraform/modules/ecr/variables.tf" <<'EOF'
variable "project_name" { type = string }
EOF

cat > "${ROOT}/terraform/modules/ecr/main.tf" <<'EOF'
resource "aws_ecr_repository" "patient" {
  name                         = "${var.project_name}-patient"
  image_tag_mutability         = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
}

resource "aws_ecr_repository" "appointment" {
  name                         = "${var.project_name}-appointment"
  image_tag_mutability         = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
}

output "patient_repo_url"     { value = aws_ecr_repository.patient.repository_url }
output "appointment_repo_url" { value = aws_ecr_repository.appointment.repository_url }
EOF

cat > "${ROOT}/terraform/modules/ecs/variables.tf" <<'EOF'
variable "project_name"             { type = string }
variable "vpc_id"                   { type = string }
variable "public_subnet_ids"        { type = list(string) }
variable "private_subnet_ids"       { type = list(string) }
variable "task_exec_role_arn"       { type = string }
variable "task_role_arn"            { type = string }
variable "ecr_patient_repo_url"     { type = string }
variable "ecr_appointment_repo_url" { type = string }
variable "aws_region"               { type = string }
EOF

cat > "${ROOT}/terraform/modules/ecs/main.tf" <<'EOF'
resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-cluster"
  setting { name = "containerInsights", value = "enabled" }
}

resource "aws_lb" "alb" {
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "patient" {
  name        = "${var.project_name}-tg-patient"
  port        = 3001
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
  health_check { path = "/health" }
}

resource "aws_lb_target_group" "appointment" {
  name        = "${var.project_name}-tg-appointment"
  port        = 3002
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
  health_check { path = "/health" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response { content_type = "text/plain", message_body = "Route not found", status_code = "404" }
  }
}

resource "aws_lb_listener_rule" "patient_rule" {
  listener_arn = aws_lb_listener.http.arn
  action { type = "forward", target_group_arn = aws_lb_target_group.patient.arn }
  condition { path_pattern { values = ["/patient*", "/health"] } }
}

resource "aws_lb_listener_rule" "appointment_rule" {
  listener_arn = aws_lb_listener.http.arn
  action { type = "forward", target_group_arn = aws_lb_target_group.appointment.arn }
  condition { path_pattern { values = ["/appointment*"] } }
}

resource "aws_cloudwatch_log_group" "patient" {
  name              = "/ecs/${var.project_name}/patient"
  retention_in_days = 14
}
resource "aws_cloudwatch_log_group" "appointment" {
  name              = "/ecs/${var.project_name}/appointment"
  retention_in_days = 14
}

resource "aws_security_group" "svc" {
  name   = "${var.project_name}-svc-sg"
  vpc_id = var.vpc_id
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_lb.alb.security_groups[0]]
    description     = "From ALB"
  }
  egress { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_ecs_task_definition" "patient" {
  family                   = "${var.project_name}-patient"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.task_exec_role_arn
  task_role_arn            = var.task_role_arn
  container_definitions = jsonencode([{
    name      = "patient"
    image     = "${var.ecr_patient_repo_url}:latest"
    essential = true
    portMappings = [{ containerPort = 3001, protocol = "tcp" }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.patient.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
      }
    }
    environment = [{ name = "NODE_ENV", value = "production" }]
  }])
}

resource "aws_ecs_task_definition" "appointment" {
  family                   = "${var.project_name}-appointment"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.task_exec_role_arn
  task_role_arn            = var.task_role_arn
  container_definitions = jsonencode([{
    name      = "appointment"
    image     = "${var.ecr_appointment_repo_url}:latest"
    essential = true
    portMappings = [{ containerPort = 3002, protocol = "tcp" }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.appointment.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
      }
    }
    environment = [{ name = "NODE_ENV", value = "production" }]
  }])
}

resource "aws_ecs_service" "patient" {
  name            = "${var.project_name}-patient"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.patient.arn
  launch_type     = "FARGATE"
  desired_count   = 1
  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.svc.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.patient.arn
    container_name   = "patient"
    container_port   = 3001
  }
  depends_on = [aws_lb_listener.http]
}

resource "aws_ecs_service" "appointment" {
  name            = "${var.project_name}-appointment"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.appointment.arn
  launch_type     = "FARGATE"
  desired_count   = 1
  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.svc.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.appointment.arn
    container_name   = "appointment"
    container_port   = 3002
  }
  depends_on = [aws_lb_listener.http]
}

output "alb_dns_name" { value = aws_lb.alb.dns_name }
output "cluster_name" { value = aws_ecs_cluster.this.name }
output "alb_arn"      { value = aws_lb.alb.arn }
EOF

cat > "${ROOT}/terraform/modules/observability/variables.tf" <<'EOF'
variable "project_name"     { type = string }
variable "ecs_cluster_name" { type = string }
variable "alb_arn"          { type = string }
variable "aws_region"       { type = string }
EOF

cat > "${ROOT}/terraform/modules/observability/main.tf" <<'EOF'
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.project_name}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  dimensions = {
    LoadBalancer = replace(var.alb_arn, "arn:aws:elasticloadbalancing:${var.aws_region}:", "")
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.project_name}-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  dimensions = { ClusterName = var.ecs_cluster_name }
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6,
        properties = {
          metrics = [["AWS/ECS","CPUUtilization","ClusterName",var.ecs_cluster_name]],
          period  = 60, stat = "Average", title = "ECS Cluster CPU"
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6,
        properties = {
          metrics = [["AWS/ApplicationELB","HTTPCode_ELB_5XX_Count","LoadBalancer", replace(var.alb_arn, "arn:aws:elasticloadbalancing:${var.aws_region}:", "") ]],
          period  = 60, stat = "Sum", title = "ALB 5xx"
        }
      }
    ]
  })
}
EOF

# --- GitHub Actions workflows ---
cat > "${ROOT}/.github/workflows/terraform-iac.yml" <<'EOF'
name: Terraform IaC
on:
  pull_request:
    paths: ["terraform/**"]
  push:
    branches: ["main"]
    paths: ["terraform/**"]
env:
  AWS_REGION: ap-southeast-2

jobs:
  fmt-validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - name: Terraform fmt
        working-directory: terraform
        run: terraform fmt -check -recursive
      - name: Terraform init (dev)
        working-directory: terraform
        run: terraform init -backend-config=env/dev.tfvars
      - name: Terraform validate
        working-directory: terraform
        run: terraform validate

  plan:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_IAC_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}
      - uses: hashicorp/setup-terraform@v3
      - name: Terraform init
        working-directory: terraform
        run: terraform init -backend-config=env/dev.tfvars
      - name: Select workspace based on PR base
        id: ws
        run: |
          env="${{ github.base_ref }}"
          if [ "$env" = "main" ] || [ "$env" = "prod" ]; then ws="prod";
          elif [ "$env" = "staging" ]; then ws="staging";
          else ws="dev"; fi
          echo "ws=$ws" >> $GITHUB_OUTPUT
      - name: Terraform workspace select
        working-directory: terraform
        run: terraform workspace select ${{ steps.ws.outputs.ws }} || terraform workspace new ${{ steps.ws.outputs.ws }}
      - name: Terraform plan
        working-directory: terraform
        run: terraform plan -var-file=env/${{ steps.ws.outputs.ws }}.tfvars

  apply:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_IAC_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}
      - uses: hashicorp/setup-terraform@v3
      - name: Terraform init
        working-directory: terraform
        run: terraform init -backend-config=env/prod.tfvars
      - name: Terraform workspace select prod
        working-directory: terraform
        run: terraform workspace select prod
      - name: Terraform apply
        working-directory: terraform
        run: terraform apply -auto-approve -var-file=env/prod.tfvars
EOF

cat > "${ROOT}/.github/workflows/app-ci-cd.yml" <<'EOF'
name: App CI/CD
on:
  push:
    branches: ["main", "staging", "dev"]
    paths: ["app/**", ".github/workflows/app-ci-cd.yml"]
env:
  AWS_REGION: ap-southeast-2
  PROJECT: clinic-microservices

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: [patient-service, appointment-service]
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_APP_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}
      - uses: aws-actions/amazon-ecr-login@v2

      - name: Set repo URLs
        id: repos
        run: |
          ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
          if [ "${{ matrix.service }}" = "patient-service" ]; then
            REPO="${ACCOUNT_ID}.dkr.ecr.${{ env.AWS_REGION }}.amazonaws.com/${{ env.PROJECT }}-patient";
          else
            REPO="${ACCOUNT_ID}.dkr.ecr.${{ env.AWS_REGION }}.amazonaws.com/${{ env.PROJECT }}-appointment";
          fi
          echo "repo=$REPO" >> $GITHUB_OUTPUTbootstrap-structure.sh
          echo "tag=${GITHUB_SHA}" >> $GITHUB_OUTPUT

      - name: Build image
        working-directory: app/${{ matrix.service }}
        run: docker build -t ${{ steps.repos.outputs.repo }}:${{ steps.repos.outputs.tag }} .

      - name: Push SHA tag
        run: docker push ${{ steps.repos.outputs.repo }}:${{ steps.repos.outputs.tag }}

      - name: Tag latest (for Terraform task defs)
        run: |
          docker tag ${{ steps.repos.outputs.repo }}:${{ steps.repos.outputs.tag }} ${{ steps.repos.outputs.repo }}:latest
          docker push ${{ steps.repos.outputs.repo }}:latest

  deploy-ecs:
    needs: build-and-push
    runs-on: ubuntu-latest
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_APP_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}
      - name: Force new deployment of services
        run: |
          CLUSTER="${{ env.PROJECT }}-cluster"
          for svc in "${{ env.PROJECT }}-patient" "${{ env.PROJECT }}-appointment"; do
            aws ecs update-service --cluster "$CLUSTER" --service "$svc" --force-new-deployment >/dev/null
            echo "Deployment triggered for $svc"
          done
EOF

echo "✅ Done. To view the tree:"
echo "   tree -a ${ROOT}  # if 'tree' is installed"
