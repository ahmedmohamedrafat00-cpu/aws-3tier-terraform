provider "aws" {
  region = var.aws_region
}

module "networking" {
  source = "../../modules/networking"

  network_cidr = var.network_cidr
  azs          = var.availability_zones
}
module "database" {
  source = "../../modules/database"

  vpc_id        = module.networking.vpc_id
  db_subnet_ids = module.networking.db_subnets
  backend_sg_id = module.compute.backend_sg_id
}
module "compute" {
  source = "../../modules/compute"

  vpc_id          = module.networking.vpc_id
  public_subnets  = module.networking.public_subnets
  private_subnets = module.networking.private_subnets

  db_host = module.database.db_endpoint

  my_ip    = "197.196.248.139"
  key_name = "supplier-app"
}

