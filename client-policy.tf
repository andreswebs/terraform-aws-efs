
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

  statement {
    sid    = "AllowDescribe"
    effect = "Allow"

    actions = [
      "elasticfilesystem:DescribeMountTargets",
      "elasticfilesystem:DescribeAccessPoints",
    ]

    resources = [aws_efs_access_point.this.arn]
  }

}
