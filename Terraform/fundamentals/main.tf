terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "local" {}

locals {
  project_name = "terraform-study"
  file_label   = "${local.project_name}-${var.student_name}"
}

resource "local_file" "study" {
  filename = "${path.module}/hello.txt"
  content  = "Hello, ${var.student_name}!\n"
}

data "local_file" "existing" {
  filename   = local_file.study.filename
  depends_on = [local_file.study]
}
