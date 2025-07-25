provider "aws" {
  region = var.aws_region
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "mock_access_key"
  secret_key                  = "mock_secret_key"
}

#data "aws_caller_identity" "current" {}
#data "aws_availability_zones" "available" {
#  state = "available"
#}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.0.0"

  name = "coalfire-vpc"
  cidr = "10.1.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets  = ["10.1.0.0/24", "10.1.1.0/24"]
  private_subnets = ["10.1.2.0/24", "10.1.3.0/24"]

  enable_nat_gateway = true
}

resource "aws_instance" "standalone" {
  ami                    = var.redhat_ami
  instance_type          = "t2.micro"
  subnet_id              = module.vpc.public_subnets[1]
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_write_logs_profile.name

  root_block_device {
    volume_size = 20
    volume_type = "gp2"
  }

  tags = {
    Name = "standalone-ec2"
  }
}

module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "9.0.0"
  name = "coalfire-asg"
  
  min_size             = 2
  max_size             = 6
  health_check_type    = "EC2"
  availability_zones   = module.vpc.azs
  vpc_zone_identifier  = module.vpc.private_subnets
  
  launch_template_name = "coalfire-asg" 
  image_id      = var.redhat_ami
  instance_type = "t2.micro"
  ebs_optimized = true
  enable_monitoring = true
  security_groups = [aws_security_group.private_sg.id]
    
  block_device_mappings = [{
      device_name = "/dev/xvda"
      ebs = {
        delete_on_termination = true
        encrypted = true
        volume_size = 20
        volume_type = "gp2"
      }
    }]
    user_data = base64encode(templatefile("${path.module}/templates/user_data.sh", {}))
  }

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.17.0"
  name             = "coalfire-alb"
  vpc_id           = module.vpc.vpc_id
  load_balancer_type = "application"
  subnets            = module.vpc.public_subnets
  
  security_group_ingress_rules = {
    inbound_http = {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_ipv4 = [var.allowed_ips]
  }
    inbound_https = {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_ipv4 = [var.allowed_ips]
  }
}
security_group_egress_rules = {
    outbound = {
      protocol    = "-1"
         cidr_ipv4 = ["10.1.2.0/24","10.1.3.0/24"]
  }
}

listeners = {
    http-redirect-to-https = {
      port     = 80
      protocol = "HTTP"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
    https-conf = {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = "arn:aws:iam::${var.account_id}:coalfire-certificates/mauro_cert-1234"

      forward = {
        target_group_key = "private_instances"
      }
    }
  }

  target_groups = {
    private_instances = {
      name_prefix      = "cf-"
      protocol = "HTTP"
      port     = 80
      target_type      = "instance"
      }
  }
}

module "s3_images" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.2.0"

  bucket = var.images_bucket_name
  acl = "private"

  lifecycle_rule = [
    {
      id      = "memes-to-glacier"
      enabled = true
      prefix  = "memes/"
      transition = [
        {
          days          = 90
          storage_class = "GLACIER"
        }
      ]
    }
  ]
}

module "s3_logs" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.2.0"

  bucket = var.logs_bucket_name
  acl = "private"

  lifecycle_rule = [
    {
      id      = "active-to-glacier"
      enabled = true
      prefix  = "active/"
      transitions = [
        {
          days          = 90
          storage_class = "GLACIER"
        }
      ]
    },
    {
      id      = "inactive-expire"
      enabled = true
      prefix  = "inactive/"
      expiration = { days = 90 }
    }
  ]
}

resource "aws_security_group" "private_sg" {
  name        = "private-sg"
  description = "Allow HTTPS from ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks = [var.allowed_ips]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
 
resource "aws_security_group" "public_sg" {
  name        = "public-sg"
  description = "Allow HTTP and SSH from anywhere"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ips]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ips]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 1) Role to read from "images" bucket
resource "aws_iam_role" "asg_read_images" {
  name               = "asg-read-images-role"
  assume_role_policy = data.aws_iam_policy_document.asg_assume_role.json
}

data "aws_iam_policy_document" "asg_read_images" {
  statement {
    sid    = "ASGS3GetImages"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.images_bucket_name}",
      "arn:aws:s3:::${var.images_bucket_name}/*"
    ]
  }
}

resource "aws_iam_policy" "asg_read_images_policy" {
  name   = "ASGReadImagesPolicy"
  policy = data.aws_iam_policy_document.asg_read_images.json
}

resource "aws_iam_role_policy_attachment" "asg_read_images_attach" {
  role       = aws_iam_role.asg_read_images.name
  policy_arn = aws_iam_policy.asg_read_images_policy.arn
}

resource "aws_iam_instance_profile" "asg_read_images_profile" {
  name = "asg-read-images-profile"
  role = aws_iam_role.asg_read_images.name
}

# Role for EC2 to write logs into "logs" bucket
resource "aws_iam_role" "ec2_write_logs" {
  name               = "ec2-write-logs-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

data "aws_iam_policy_document" "ec2_write_logs" {
  statement {
    sid    = "S3WriteLogs"
    effect = "Allow"
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::${var.logs_bucket_name}/*"
    ]
  }
}

resource "aws_iam_policy" "ec2_write_logs_policy" {
  name   = "EC2WriteLogsPolicy"
  policy = data.aws_iam_policy_document.ec2_write_logs.json
}

resource "aws_iam_role_policy_attachment" "ec2_write_logs_attach" {
  role       = aws_iam_role.ec2_write_logs.name
  policy_arn = aws_iam_policy.ec2_write_logs_policy.arn
}

resource "aws_iam_instance_profile" "ec2_write_logs_profile" {
  name = "ec2-write-logs-profile"
  role = aws_iam_role.ec2_write_logs.name
}

# Common assume-role
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "asg_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}