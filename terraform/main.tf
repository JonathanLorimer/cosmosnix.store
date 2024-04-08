terraform {
  required_version = ">= 1.6.4"

  backend "s3" {
    bucket         = "cosmosnixstore-remote-terraform-state"
    key            = "cosmosnixstore-tf/terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }

  required_providers {
    aws = {
      version = "~> 5.26.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

resource "aws_s3_bucket" "cosmosnix_store" {
  bucket = "cosmosnix-store"
  force_destroy = true
}

resource "aws_s3_bucket_policy" "allow_anonymous_reads" {
  bucket = aws_s3_bucket.cosmosnix_store.id
  policy = jsonencode({
    "Id" : "DirectReads",
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowDirectReads",
        "Action" : [
          "s3:GetObject",
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:ListMultipartUploadParts",
        ],
        "Effect" : "Allow",
        "Resource" : [
          "arn:aws:s3:::cosmosnix-store",
          "arn:aws:s3:::cosmosnix-store/*"
        ],
        "Principal" : "*"
      }
    ]
  })
}

module "oidc_github" {
  source  = "unfunco/oidc-github/aws"
  version = "1.7.1"
  enabled = true

  github_repositories = [
    "informalsystems/cosmos.nix",
  ]
}

resource "aws_iam_role" "push_cosmosnix_store" {
  name = "push-cosmosnix-store"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : [
            "arn:aws:iam::762411426253:user/Jonathan"
          ]
        },
        "Action" : "sts:AssumeRole",
      },
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "${module.oidc_github.oidc_provider_arn}"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com"
          }
          "ForAnyValue:StringLike" : {
            "token.actions.githubusercontent.com:sub" : [
              "repo:informalsystems/cosmos.nix:*",
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "push_cosmosnix_store_policy" {
  name = "push_cosmosnix_store"
  role = aws_iam_role.push_cosmosnix_store.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "PushCosmosnixStore",
        "Effect" : "Allow",
        "Action" : [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:ListMultipartUploadParts",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:DeleteObjects",
          "s3:DeleteObjectVersion"
        ],
        "Resource" : [
          "arn:aws:s3:::cosmosnix-store",
          "arn:aws:s3:::cosmosnix-store/*"
        ]
      }
    ]
    }
  )
}

resource "aws_s3_bucket_versioning" "cosmosnixstore_versioning" {
  bucket = aws_s3_bucket.cosmosnix_store.id
  versioning_configuration {
    status = "Enabled"
  }
}
