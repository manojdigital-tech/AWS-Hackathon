variable "aws_region"          { type = string, default = "ap-southeast-2" }
variable "azs"                 { type = list(string), default = ["ap-southeast-2a", "ap-southeast-2b"] }
variable "tfstate_bucket_name" { type = string }
variable "tfstate_lock_table"  { type = string }
variable "project_name"        { type = string, default = "clinic-microservices" }
variable "app_domain"          { type = string, default = null }
