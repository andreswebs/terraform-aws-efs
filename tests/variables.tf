variable "name" {
  type = string
}

variable "kms_key_arn" {
  type    = string
  default = null
}

variable "subnet_ids" {
  type = list(string)
  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "Must contain at least one."
  }
}

variable "allowed_security_group_ids" {
  type = list(string)
  validation {
    condition     = length(var.allowed_security_group_ids) > 0
    error_message = "Must contain at least one."
  }
}

variable "app_uid" {
  type    = number
  default = 2000
}

variable "app_gid" {
  type    = number
  default = 2000
}

variable "root_dir_permissions" {
  type    = number
  default = 0750
}

variable "root_dir_path" {
  type    = string
  default = "/data"
}

variable "allowed_principal_arns" {
  type    = list(string)
  default = []
}
