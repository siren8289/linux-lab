output "file_path" {
  value = local_file.study.filename
}

output "file_content" {
  value = local_file.study.content
}

output "file_label" {
  value = local.file_label
}

output "existing_file_content" {
  value = data.local_file.existing.content
}
