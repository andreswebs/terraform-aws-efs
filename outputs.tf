output "file_system" {
  value = aws_efs_file_system.this
}

output "access_point" {
  value = var.enable_access_point ? aws_efs_access_point.this : null
}

output "client_policy_document" {
  value = data.aws_iam_policy_document.client
}

output "client_security_group" {
  value = aws_security_group.client
}
