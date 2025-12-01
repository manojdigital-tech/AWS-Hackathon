# Clinic Microservices Starter

Dockerized Node.js microservices deployed on AWS ECS Fargate via Terraform,
with remote state (S3 + DynamoDB), multi-environment workspaces, and GitHub Actions CI/CD.

See `terraform/env/*.tfvars` for environment-specific values.


Project Architecture:
clinic-microservices-starter/
├── README.md
├── app/
│   ├── patient-service/
│   │   ├── Dockerfile
│   │   ├── .dockerignore
│   │   ├── package.json
│   │   └── src/index.js        # uses PORT=3001, /health endpoint
│   ├── appointment-service/
│   │   ├── Dockerfile
│   │   ├── .dockerignore
│   │   ├── package.json
│   │   └── src/index.js        # uses PORT=3002, /health endpoint
│   └── docker-compose.yml
├── terraform/
│   ├── versions.tf
│   ├── providers.tf
│   ├── backend.tf
│   ├── variables.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── env/
│   │   ├── dev.tfvars
│   │   ├── staging.tfvars
│   │   └── prod.tfvars
│   └── modules/
│       ├── vpc/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── iam/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── ecr/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── ecs/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── observability/
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
└── .github/
    └── workflows/
        ├── terraform-iac.yml
        └── app-ci-cd.yml

