module "terraform_ci" {
  source             = "../../modules/terraform_ci"
  github_repo        = "cosmonaut-ai/cosmonaut-infra"
  apply_environments = ["dev", "prod"]
}

import {
  to = module.terraform_ci.aws_iam_role.plan
  id = "cosmonaut-terraform-plan"
}

import {
  to = module.terraform_ci.aws_iam_role_policy_attachment.plan_read_only
  id = "cosmonaut-terraform-plan/arn:aws:iam::aws:policy/ReadOnlyAccess"
}

import {
  to = module.terraform_ci.aws_iam_role_policy.plan_secure_parameter_read
  id = "cosmonaut-terraform-plan:secure-parameter-read"
}

import {
  to = module.terraform_ci.aws_iam_role.apply
  id = "cosmonaut-terraform-apply"
}

import {
  to = module.terraform_ci.aws_iam_role_policy_attachment.apply_admin
  id = "cosmonaut-terraform-apply/arn:aws:iam::aws:policy/AdministratorAccess"
}

output "terraform_plan_role_arn" {
  value = module.terraform_ci.plan_role_arn
}

output "terraform_apply_role_arn" {
  value = module.terraform_ci.apply_role_arn
}
