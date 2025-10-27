data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

data "aws_subnet" "this" {
  for_each = toset(var.subnet_ids)
  id       = each.value
}

data "aws_subnet" "selected" {
  id = var.subnet_ids[0]
}

locals {
  partition  = data.aws_partition.current.partition
  account_id = data.aws_caller_identity.current.account_id
}

locals {
  vpc_id               = data.aws_subnet.selected.vpc_id
  subnet_cidrs_ipv4    = [for s in data.aws_subnet.this : s.cidr_block]
  nfs_port             = 2049
  sg_name_mount_target = var.mount_target_security_group_name != null && var.mount_target_security_group_name != "" ? var.mount_target_security_group_name : "${var.name}-efs-mount-target"
}

resource "aws_efs_file_system" "this" {
  creation_token   = var.name
  encrypted        = true
  kms_key_id       = var.kms_key_arn
  throughput_mode  = var.throughput_mode
  performance_mode = var.performance_mode

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_efs_backup_policy" "this" {
  file_system_id = aws_efs_file_system.this.id
  backup_policy {
    status = "ENABLED"
  }
}

resource "aws_security_group" "mount_target" {
  vpc_id      = local.vpc_id
  name        = local.sg_name_mount_target
  description = var.mount_target_security_group_description

  revoke_rules_on_delete = true

  tags = merge(var.tags, {
    Name = local.sg_name_mount_target
  })
}

resource "aws_vpc_security_group_ingress_rule" "mount_target" {
  count = var.enable_allowed_security_group ? 1 : 0

  description                  = "Allow access to EFS from client security group ${var.allowed_security_group_id}"
  security_group_id            = aws_security_group.mount_target.id
  ip_protocol                  = "tcp"
  from_port                    = local.nfs_port
  to_port                      = local.nfs_port
  referenced_security_group_id = var.allowed_security_group_id

  tags = merge(var.tags, {
    Name = "from-${var.allowed_security_group_id}"
  })
}

resource "aws_vpc_security_group_egress_rule" "client" {
  count = var.enable_allowed_security_group ? 1 : 0

  description                  = "Allow access to ${var.name} EFS mount point security group"
  security_group_id            = var.allowed_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = local.nfs_port
  to_port                      = local.nfs_port
  referenced_security_group_id = aws_security_group.mount_target.id

  tags = merge(var.tags, {
    Name = "to-${var.name}-efs"
  })
}

resource "aws_efs_mount_target" "this" {
  for_each        = toset(var.subnet_ids)
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value
  security_groups = [aws_security_group.mount_target.id]
}

resource "aws_efs_access_point" "this" {
  count          = var.enable_access_point ? 1 : 0
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    uid = try(var.access_point_config.posix_user.uid, null)
    gid = try(var.access_point_config.posix_user.gid, null)
  }

  root_directory {
    path = try(var.access_point_config.root_directory.path, null)

    creation_info {
      owner_uid   = try(var.access_point_config.root_directory.creation_info.owner_uid, null)
      owner_gid   = try(var.access_point_config.root_directory.creation_info.owner_gid, null)
      permissions = try(var.access_point_config.root_directory.creation_info.permissions, null)
    }
  }
}

data "aws_iam_policy_document" "this" {
  statement {
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = ["*"]

    resources = [aws_efs_file_system.this.arn]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_efs_file_system_policy" "this" {
  file_system_id = aws_efs_file_system.this.id
  policy         = data.aws_iam_policy_document.this.json
}
