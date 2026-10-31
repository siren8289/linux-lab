module "api" {
  source = "./modules/app-config"

  name = "study-api"
  port = 8080
}

output "api_config" {
  value = module.api.config
}
