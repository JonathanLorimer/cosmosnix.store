terraform {
  required_version = ">= 1.6.4"
  required_providers {
    aws = {
      version = "~> 5.26.0"
    }
  }
  # backend "local" {}
  backend "s3" {
    bucket         = "cosmosnixstore-remote-terraform-state"
    key            = "cosmosnixstore-remote-state/terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}

provider "aws" {
  region = "us-east-2"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "cosmosnixstore-remote-terraform-state"
}

# Resource to avoid error "AccessControlListNotSupported: The bucket does not allow ACLs"
resource "aws_s3_bucket_ownership_controls" "terraform_state_acl_ownership" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_acl" "terraform_state_acl" {
  bucket     = aws_s3_bucket.terraform_state.id
  acl        = "private"
  depends_on = [aws_s3_bucket_ownership_controls.terraform_state_acl_ownership]
}

resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "terraform_lock" {
  name         = "cosmosnixstore-terraform-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

resource "aws_iam_policy" "cosmosnixstore_tf_state_s3_bucket_policy" {
  name        = "cosmosnixstore_tf_state_s3_bucket"
  path        = "/"
  description = "Terraform Remote State S3 Bucket"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "s3:ListBucket",
        "Resource" : "arn:aws:s3:::mybucket"
      },
      {
        "Effect" : "Allow",
        "Action" : ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
        "Resource" : "arn:aws:s3:::cosmosnixstore-remote-state/terraform.tfstate"
      }
    ]
  })
}

resource "aws_iam_policy" "cosmosnixstore_tf_state_lock_policy" {
  name        = "cosmosnixstore_tf_state_lock"
  path        = "/"
  description = "Terraform State Lock"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ],
        "Resource" : "arn:aws:dynamodb:*:*:table/mytable"
      }
    ]
    }
  )
}

resource "aws_iam_role" "terraform" {
  name = "CosmosNixTerraform"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  managed_policy_arns = [
    aws_iam_policy.cosmosnixstore_tf_state_lock_policy.arn,
    aws_iam_policy.cosmosnixstore_tf_state_s3_bucket_policy.arn
  ]

  tags = {
    tag-key = "Terraform"
  }
}
