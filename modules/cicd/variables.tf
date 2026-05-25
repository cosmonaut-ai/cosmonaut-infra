variable "env" {
  description = "Environment name (dev/prod)"
  type        = string
}

variable "github_repos" {
  description = "The list of GitHub repositories in 'owner/repo' format"
  type        = list(string)
}

variable "github_allowed_refs" {
  description = "Git refs allowed to assume the GitHub Actions deploy role"
  type        = list(string)
  default     = ["refs/heads/main", "refs/heads/develop"]
}

variable "deploy_envs" {
  description = "Cosmonaut environments the shared GitHub Actions role can deploy"
  type        = list(string)
  default     = ["dev", "prod"]
}
