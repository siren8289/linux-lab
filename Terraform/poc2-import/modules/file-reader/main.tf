variable "filename" {
  type = string
}

data "local_file" "input" {
  filename = var.filename
}

output "content" {
  value = data.local_file.input.content
}
