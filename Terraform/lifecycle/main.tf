terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

resource "local_file" "kept" {
  filename = "${path.module}/kept.txt"
  content  = "keep\n"

  lifecycle {
    prevent_destroy = true
  }
}

resource "local_file" "quiet" {
  filename = "${path.module}/quiet.txt"
  content  = "one\n"

  lifecycle {
    ignore_changes = [content]
  }
}
