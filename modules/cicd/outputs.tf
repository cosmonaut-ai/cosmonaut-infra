output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "repository_url" {
  value = aws_ecr_repository.repo.repository_url
}
