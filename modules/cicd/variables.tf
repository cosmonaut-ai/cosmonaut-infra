variable "env" {
  description = "Environment name (dev/prod)"
  type        = string
}

variable "github_repos" {
  description = "The list of GitHub repositories in 'owner/repo' format"
  type        = list(string)
}
