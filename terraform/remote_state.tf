# Lê os outputs do repositório soat-fiap-oficina-mecanica-infra-kube (VPC/subnets)
# para colocar a Lambda na mesma rede privada do cluster e do RDS.
data "terraform_remote_state" "infra_kube" {
  backend = "s3"

  config = {
    bucket = var.tf_state_bucket
    key    = "oficina-mecanica/infra-kube/terraform.tfstate"
    region = var.aws_region
  }
}

# Lê o security group do RDS (soat-fiap-oficina-mecanica-infra-data) para liberar
# o acesso da Lambda ao banco, sem duplicar o provisionamento do banco em si.
data "terraform_remote_state" "infra_data" {
  backend = "s3"

  config = {
    bucket = var.tf_state_bucket
    key    = "oficina-mecanica/infra-data/terraform.tfstate"
    region = var.aws_region
  }
}
