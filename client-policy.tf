locals {
  client_conditions = [
    {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["true"]
    },
    var.enable_access_point ? {
      test     = "StringEquals"
      variable = "elasticfilesystem:AccessPointArn"
      values   = [aws_efs_access_point.this[0].arn]
      } : {
      test     = "Bool"
      variable = "elasticfilesystem:AccessedViaMountTarget"
      values   = ["true"]
    }
  ]
}

data "aws_iam_policy_document" "client" {
  statement {
    sid    = "AllowClient"
    effect = "Allow"

    actions = compact([
      var.enable_client_root_access ? "elasticfilesystem:ClientRootAccess" : "",
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite",
      "elasticfilesystem:DescribeFileSystems",
      "elasticfilesystem:DescribeMountTargets",
      "elasticfilesystem:DescribeAccessPoints",
    ])

    resources = [aws_efs_file_system.this.arn]

    dynamic "condition" {
      for_each = local.client_conditions
      content {
        test     = condition.value.test
        variable = condition.value.variable
        values   = condition.value.values
      }
    }

  }

}
