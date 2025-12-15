provider "aws" {
  region = var.aws_region
}

module "networking" {
  source = "../../modules/networking"

  network_cidr = var.network_cidr
  azs          = var.availability_zones
}

