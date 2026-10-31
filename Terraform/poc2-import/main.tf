terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

# local_file and null_resource in the current providers do not implement import.
# terraform_data is a Terraform core resource that does.
# The import ID is the absolute path of the existing file.
locals {
  filename = abspath("${path.module}/existing.txt")
}

resource "terraform_data" "existing" {}

module "reader" {
  source   = "./modules/file-reader"
  filename = local.filename
}

output "imported_id" {
  value = terraform_data.existing.id
}

output "imported_content" {
  value = module.reader.content
}
