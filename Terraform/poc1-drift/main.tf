terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

variable "environment" {
  type    = string
  default = "dev"
}

resource "local_file" "config" {
  filename = "${path.module}/config.txt"
  content  = "environment=${var.environment}\n"
}

output "config_path" {
  value = local_file.config.filename
}
