output "file_system" {
  value = aws_efs_file_system.this
}

output "access_point" {
  value = aws_efs_access_point.this
}

output "client_policy" {
  value = data.aws_iam_policy_document.client
}
