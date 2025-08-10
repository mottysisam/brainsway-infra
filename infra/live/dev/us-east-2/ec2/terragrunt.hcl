include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/ec2" }
inputs = {
  "instances" = {
    "aurora-jump-server-dev" = {
      "ami"                         = "ami-0b0884a542ed17bc8"
      "instance_type"               = "t3.micro"
      "subnet_id"                   = "subnet-0e0e2c0c8eef2ddd4"  # dev public subnet us-east-2a
      "vpc_security_group_ids"      = ["sg-015be9b3f03be37e0"]    # development-database-access-sg
      "associate_public_ip_address" = true
      "tags" = {
        "Name" = "aurora-jump-server-dev"
        "Environment" = "dev"
        "Purpose" = "jump-server"
      }
    },
    "insights-dev-backend" = {
      "ami"                    = "ami-0b0884a542ed17bc8"
      "instance_type"          = "t2.large"
      "subnet_id"             = "subnet-01d98fae21a21498d"  # dev private subnet us-east-2b
      "vpc_security_group_ids" = ["sg-04bdd451db6d8829a"]    # development-app-tier-sg
      "associate_public_ip_address" = false
      "tags" = {
        "Name" = "insights-dev-backend"
        "Environment" = "dev"
        "Purpose" = "backend"
      }
    },
    "insights-dev-frontend" = {
      "ami"                    = "ami-0b0884a542ed17bc8"
      "instance_type"          = "r6in.large"
      "subnet_id"             = "subnet-06942df65eb5127da"  # dev private subnet us-east-2c
      "vpc_security_group_ids" = ["sg-049dfb39cef413e32"]    # development-web-tier-sg
      "associate_public_ip_address" = false
      "tags" = {
        "Name" = "insights-dev-frontend"
        "Environment" = "dev"
        "Purpose" = "frontend"
      }
    }
  }
}
