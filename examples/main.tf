module "efs" {
  source                     = "github.com/andreswebs/terraform-aws-efs"
  name                       = var.name
  subnet_ids                 = var.subnet_ids
  allowed_security_group_ids = var.allowed_security_group_ids
  allowed_principal_arns     = var.allowed_principal_arns
}
