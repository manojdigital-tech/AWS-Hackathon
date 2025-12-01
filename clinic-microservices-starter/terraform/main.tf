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
