################################################################################
# ECR - Repositório de imagens Docker
# Nome: bia
# URI: 328958872848.dkr.ecr.us-east-1.amazonaws.com/bia
################################################################################

resource "aws_ecr_repository" "bia" {
  name                 = "bia"
  image_tag_mutability = "MUTABLE" # permite sobrescrever tags (ex: latest, git sha)

  image_scanning_configuration {
    scan_on_push = false
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}
