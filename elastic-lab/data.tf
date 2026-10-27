data "aws_availability_zones" "available" {
  state = "available"
}

# Latest Amazon Linux 2023 image
data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_caller_identity" "current" {}
