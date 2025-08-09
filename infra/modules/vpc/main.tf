terraform { 
  required_providers { 
    aws = { 
      source  = "hashicorp/aws" 
      version = ">= 5.0" 
    } 
  } 
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge({ Name = "core-vpc" }, var.tags)
}