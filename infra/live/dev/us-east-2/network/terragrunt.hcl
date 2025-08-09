include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/network" }
inputs = {
  # Basic VPC configuration for dev environment testing
  vpc = {
    cidr_block = "10.0.0.0/16"
    tags = {
      Name = "dev-vpc"
    }
  }
  
  # Basic subnet configuration for minimal functionality
  subnets = {
    "subnet-dev-public-1" = {
      vpc_id                  = "vpc-placeholder"  # Will be replaced during import
      cidr_block              = "10.0.1.0/24"
      availability_zone       = "us-east-2a"
      map_public_ip_on_launch = true
      tags = {
        Name = "dev-public-subnet-1"
        Type = "public"
      }
    }
    "subnet-dev-private-1" = {
      vpc_id        = "vpc-placeholder"  # Will be replaced during import
      cidr_block    = "10.0.10.0/24"
      availability_zone = "us-east-2a"
      tags = {
        Name = "dev-private-subnet-1"
        Type = "private"
      }
    }
  }
  
  # Internet gateway for public subnet connectivity
  internet_gateways = ["igw-placeholder"]
  
  # Basic security group for development
  security_groups = {
    "sg-dev-default" = {
      name        = "dev-default"
      description = "Default security group for dev environment"
      vpc_id      = "vpc-placeholder"  # Will be replaced during import
      tags = {
        Name = "dev-default-sg"
      }
    }
  }
}
