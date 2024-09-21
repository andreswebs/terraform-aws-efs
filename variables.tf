variable "name" {
  type = string
}

variable "kms_key_arn" {
  type    = string
  default = null
}

variable "throughput_mode" {
  type    = string
  default = "elastic"
  validation {
    condition     = can(regex("^(bursting|elastic)$", var.throughput_mode))
    error_message = "The input must be either 'bursting' or 'elastic'."
  }
}

variable "subnet_ids" {
  type = list(string)

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "Must contain at least one."
  }
}

variable "allowed_security_group_ids" {
  type    = list(string)
  default = []
}

variable "enable_client_root_access" {
  type    = bool
  default = false
}

variable "access_point_config" {
  type = object({
    posix_user = optional(object({
      uid = optional(number)
      gid = optional(number)
    }))
    root_directory = optional(object({
      path = optional(string)
      creation_info = optional(object({
        owner_uid   = optional(number)
        owner_gid   = optional(number)
        permissions = optional(number)
      }))
    }))
  })
  default = null
}

variable "enable_access_point" {
  type    = bool
  default = false
}
