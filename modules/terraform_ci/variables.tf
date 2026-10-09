variable "github_repo" {
  description = "Repository allowed to run Terraform from GitHub Actions, in 'owner/repo' format"
  type        = string
}

variable "apply_environments" {
  description = "GitHub environments in github_repo whose jobs may assume the apply role"
  type        = list(string)
}

variable "plan_role_name" {
  description = "Name of the read-only role used for pull request plans"
  type        = string
  default     = "cosmonaut-terraform-plan"
}

variable "apply_role_name" {
  description = "Name of the admin role used for applies"
  type        = string
  default     = "cosmonaut-terraform-apply"
}
