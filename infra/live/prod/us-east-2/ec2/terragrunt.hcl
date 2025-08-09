include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/ec2" }
inputs = {
  "instances": {
    "i-034add2a3d4b5a5c7": {
      "ami": "ami-00eeedc4036573771",
      "instance_type": "r6in.large",
      "subnet_id": "subnet-40895a0d",
      "vpc_security_group_ids": [
        "sg-046ca9a7beb55e46a"
      ],
      "key_name": "FrontEndWhite1",
      "iam_instance_profile": "arn:aws:iam::154948530138:instance-profile/AmazonEC2RoleForSSM",
      "associate_public_ip_address": true,
      "tags": {
        "GuardDutyManaged": "true",
        "owner": "Udi",
        "project": "navigator",
        "Name": "insights_prod_frontend",
        "service": "Frontend",
        "createdby": "Ola"
      }
    },
    "i-0516613576e30a972": {
      "ami": "ami-0568773882d492fc8",
      "instance_type": "t3.micro",
      "subnet_id": "subnet-40895a0d",
      "vpc_security_group_ids": [
        "sg-00a1abc08cd804a5d"
      ],
      "key_name": "aurora-jump-server",
      "iam_instance_profile": "arn:aws:iam::154948530138:instance-profile/AmazonEC2RoleForSSM",
      "associate_public_ip_address": true,
      "tags": {
        "Name": "aurora-jump-server"
      }
    },
    "i-0b7b89eb25097be06": {
      "ami": "ami-00d1eab8692ab1e1b",
      "instance_type": "t2.large",
      "subnet_id": "subnet-47cb8d2e",
      "vpc_security_group_ids": [
        "sg-046ca9a7beb55e46a"
      ],
      "key_name": "FrontEndWhite1",
      "iam_instance_profile": "arn:aws:iam::154948530138:instance-profile/AmazonEC2RoleForSSM",
      "associate_public_ip_address": true,
      "tags": {
        "GuardDutyManaged": "true",
        "Name": "insights_prod_backend"
      }
    }
  }
}
