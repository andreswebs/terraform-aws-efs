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

  vpc_id            = data.aws_subnet.selected.vpc_id
  subnet_cidrs_ipv4 = [for s in data.aws_subnet.this : s.cidr_block]
  nfs_port          = 2049

  allowed_security_group_ids = compact(concat(var.allowed_security_group_ids, [aws_security_group.client.id]))

  sg_name_mount_target = "${var.name}-efs-mount-target"
  sg_name_client       = "${var.name}-efs-client"
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

resource "aws_security_group" "client" {
  vpc_id = local.vpc_id
  name   = local.sg_name_client

  revoke_rules_on_delete = true

  tags = {
    Name = local.sg_name_client
  }
}

resource "aws_vpc_security_group_egress_rule" "client" {
  for_each = toset(local.subnet_cidrs_ipv4)

  security_group_id = aws_security_group.client.id

  ip_protocol = "tcp"
  from_port   = local.nfs_port
  to_port     = local.nfs_port
  cidr_ipv4   = each.value
}

resource "aws_security_group" "mount_target" {
  vpc_id = local.vpc_id
  name   = local.sg_name_mount_target

  revoke_rules_on_delete = true

  tags = {
    Name = local.sg_name_mount_target
  }
}

resource "aws_vpc_security_group_ingress_rule" "mount_target" {
  ## Fix for 'Error: Invalid for_each argument'
  ## when using:
  ## `for_each = toset(var.allowed_security_group_ids)`
  ##
  ## 'The "for_each" set includes values derived from resource attributes that cannot be
  ## determined until apply, and so Terraform cannot determine the full set of keys that
  ## will identify the instances of this resource.'
  for_each = { for k, v in local.allowed_security_group_ids : k => v }

  security_group_id = aws_security_group.mount_target.id

  ip_protocol                  = "tcp"
  from_port                    = local.nfs_port
  to_port                      = local.nfs_port
  referenced_security_group_id = each.value
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
    uid = var.access_point_config.posix_user.uid
    gid = var.access_point_config.posix_user.gid
  }

  root_directory {
    path = var.access_point_config.root_directory.path
    creation_info {
      owner_uid   = var.access_point_config.root_directory.creation_info.owner_uid
      owner_gid   = var.access_point_config.root_directory.creation_info.owner_gid
      permissions = var.access_point_config.root_directory.creation_info.permissions
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
