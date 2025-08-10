include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/ec2" }
inputs = {
  "instances" = {
    "aurora-jump-server-staging" = {
      "ami"                         = "ami-0b0884a542ed17bc8"
      "instance_type"               = "t3.micro"
      "subnet_id"                   = "subnet-0bb2a610f508bb0b3"  # staging public subnet us-east-2a
      "vpc_security_group_ids"      = ["sg-0aa2488e7244be01b"]    # staging-database-tier-sg
      "associate_public_ip_address" = true
      "tags" = {
        "Name" = "aurora-jump-server-staging"
        "Environment" = "staging"
        "Purpose" = "jump-server"
      }
    },
    "insights-staging-backend" = {
      "ami"                    = "ami-0b0884a542ed17bc8"
      "instance_type"          = "t2.large"
      "subnet_id"             = "subnet-0d524755c7c2bd2dd"  # staging private subnet us-east-2b
      "vpc_security_group_ids" = ["sg-0eba936ee955d9735"]    # staging-app-tier-sg
      "associate_public_ip_address" = false
      "tags" = {
        "Name" = "insights-staging-backend"
        "Environment" = "staging"
        "Purpose" = "backend"
      }
    },
    "insights-staging-frontend" = {
      "ami"                    = "ami-0b0884a542ed17bc8"
      "instance_type"          = "r6in.large"
      "subnet_id"             = "subnet-0605b763393f1073a"  # staging private subnet us-east-2c
      "vpc_security_group_ids" = ["sg-0eba936ee955d9735"]    # staging-app-tier-sg
      "associate_public_ip_address" = false
      "tags" = {
        "Name" = "insights-staging-frontend"
        "Environment" = "staging"
        "Purpose" = "frontend"
      }
    }
  }
}
