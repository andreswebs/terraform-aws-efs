data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  partition  = data.aws_partition.current.partition
  account_id = data.aws_caller_identity.current.account_id
}

resource "aws_efs_file_system" "this" {
  creation_token   = var.name
  encrypted        = true
  kms_key_id       = var.kms_key_arn
  throughput_mode  = var.throughput_mode
  performance_mode = "generalPurpose"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  tags = {
    Name = var.name
  }
}

resource "aws_efs_backup_policy" "this" {
  file_system_id = aws_efs_file_system.this.id
  backup_policy {
    status = "ENABLED"
  }
}

data "aws_subnet" "selected" {
  id = var.subnet_ids[0]
}

locals {
  security_group_name = "${var.name}${var.security_group_name_suffix}"
}

resource "aws_security_group" "this" {
  vpc_id = data.aws_subnet.selected.vpc_id
  name   = local.security_group_name

  revoke_rules_on_delete = true

  tags = {
    Name = local.security_group_name
  }
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = toset(var.allowed_security_group_ids)

  security_group_id = aws_security_group.this.id

  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  referenced_security_group_id = each.value
}

resource "aws_efs_mount_target" "this" {
  for_each        = toset(var.subnet_ids)
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value
  security_groups = [aws_security_group.this.id]
}

resource "aws_efs_access_point" "this" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    uid = var.app_uid
    gid = var.app_gid
  }

  root_directory {
    path = var.root_dir_path
    creation_info {
      owner_uid   = var.app_uid
      owner_gid   = var.app_gid
      permissions = var.root_dir_permissions
    }
  }
}

locals {
  allowed_principal_arns = length(var.allowed_principal_arns) > 0 ? var.allowed_principal_arns : ["arn:${local.partition}:iam::${local.account_id}:root"]
}

data "aws_iam_policy_document" "this" {
  statement {
    sid    = "AllowClientReadWrite"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = local.allowed_principal_arns
    }

    actions = [
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite",
    ]

    resources = [aws_efs_file_system.this.arn]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["true"]
    }

    condition {
      test     = "StringEquals"
      variable = "elasticfilesystem:AccessPointArn"
      values   = [aws_efs_access_point.this.arn]
    }

  }
}

resource "aws_efs_file_system_policy" "this" {
  file_system_id = aws_efs_file_system.this.id
  policy         = data.aws_iam_policy_document.this.json
}
