include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/network" }
inputs = {
  "vpc": {
    "cidr_block": "172.31.0.0/16",
    "enable_dns_support": true,
    "enable_dns_hostnames": true,
    "tags": {
      "Name": "default"
    }
  },
  "subnets": {
    "subnet-fa22af81": {
      "vpc_id": "vpc-d2a9d9bb",
      "cidr_block": "172.31.16.0/20",
      "availability_zone": "us-east-2b",
      "map_public_ip_on_launch": true,
      "tags": {}
    },
    "subnet-40895a0d": {
      "vpc_id": "vpc-d2a9d9bb",
      "cidr_block": "172.31.32.0/20",
      "availability_zone": "us-east-2c",
      "map_public_ip_on_launch": true,
      "tags": {}
    },
    "subnet-47cb8d2e": {
      "vpc_id": "vpc-d2a9d9bb",
      "cidr_block": "172.31.0.0/20",
      "availability_zone": "us-east-2a",
      "map_public_ip_on_launch": true,
      "tags": {}
    }
  },
  "route_tables": {
    "rtb-ec83c185": {
      "vpc_id": "vpc-d2a9d9bb",
      "tags": {}
    }
  },
  "internet_gateways": [
    "igw-a14bc2c8"
  ],
  "nat_gateways": {},
  "vpc_endpoints": {
    "vpce-03e83da65d72240ba": {
      "vpc_id": "vpc-d2a9d9bb",
      "service_name": "com.amazonaws.vpce.us-east-2.vpce-svc-06bf7da21660e717b",
      "vpc_endpoint_type": "Interface",
      "subnet_ids": [
        "subnet-fa22af81",
        "subnet-40895a0d"
      ],
      "security_group_ids": [
        "sg-0c0a0065"
      ],
      "route_table_ids": [],
      "private_dns_enabled": false,
      "policy": "{\n  \"Statement\": [\n    {\n      \"Action\": \"*\", \n      \"Effect\": \"Allow\", \n      \"Principal\": \"*\", \n      \"Resource\": \"*\"\n    }\n  ]\n}",
      "tags": {}
    },
    "vpce-04045e27e5fe64d3a": {
      "vpc_id": "vpc-d2a9d9bb",
      "service_name": "com.amazonaws.vpce.us-east-2.vpce-svc-05fa0497f144c8a4a",
      "vpc_endpoint_type": "Interface",
      "subnet_ids": [
        "subnet-fa22af81",
        "subnet-47cb8d2e"
      ],
      "security_group_ids": [
        "sg-0c0a0065"
      ],
      "route_table_ids": [],
      "private_dns_enabled": false,
      "policy": "{\n  \"Statement\": [\n    {\n      \"Action\": \"*\", \n      \"Effect\": \"Allow\", \n      \"Principal\": \"*\", \n      \"Resource\": \"*\"\n    }\n  ]\n}",
      "tags": {}
    },
    "vpce-05c18f64c5b29e501": {
      "vpc_id": "vpc-d2a9d9bb",
      "service_name": "com.amazonaws.us-east-2.guardduty-data",
      "vpc_endpoint_type": "Interface",
      "subnet_ids": [
        "subnet-fa22af81",
        "subnet-40895a0d",
        "subnet-47cb8d2e"
      ],
      "security_group_ids": [
        "sg-070322ceb3fe42ccd"
      ],
      "route_table_ids": [],
      "private_dns_enabled": true,
      "policy": "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":\"*\",\"Resource\":\"*\",\"Effect\":\"Allow\",\"Principal\":\"*\"},{\"Condition\":{\"StringNotEquals\":{\"aws:PrincipalAccount\":\"154948530138\"}},\"Action\":\"*\",\"Resource\":\"*\",\"Effect\":\"Deny\",\"Principal\":\"*\"}]}",
      "tags": {}
    },
    "vpce-038ae18e92eb1b316": {
      "vpc_id": "vpc-d2a9d9bb",
      "service_name": "com.amazonaws.vpce.us-east-2.vpce-svc-094483e3c0e40c03b",
      "vpc_endpoint_type": "Interface",
      "subnet_ids": [
        "subnet-fa22af81",
        "subnet-40895a0d"
      ],
      "security_group_ids": [
        "sg-0c0a0065"
      ],
      "route_table_ids": [],
      "private_dns_enabled": false,
      "policy": "{\n  \"Statement\": [\n    {\n      \"Action\": \"*\", \n      \"Effect\": \"Allow\", \n      \"Principal\": \"*\", \n      \"Resource\": \"*\"\n    }\n  ]\n}",
      "tags": {}
    },
    "vpce-0e316e0836057e662": {
      "vpc_id": "vpc-d2a9d9bb",
      "service_name": "com.amazonaws.vpce.us-east-2.vpce-svc-06bf7da21660e717b",
      "vpc_endpoint_type": "Interface",
      "subnet_ids": [
        "subnet-fa22af81",
        "subnet-40895a0d"
      ],
      "security_group_ids": [
        "sg-0c0a0065"
      ],
      "route_table_ids": [],
      "private_dns_enabled": false,
      "policy": "{\n  \"Statement\": [\n    {\n      \"Action\": \"*\", \n      \"Effect\": \"Allow\", \n      \"Principal\": \"*\", \n      \"Resource\": \"*\"\n    }\n  ]\n}",
      "tags": {}
    },
    "vpce-0495e09585e7af9d6": {
      "vpc_id": "vpc-d2a9d9bb",
      "service_name": "com.amazonaws.vpce.us-east-2.vpce-svc-05fa0497f144c8a4a",
      "vpc_endpoint_type": "Interface",
      "subnet_ids": [
        "subnet-fa22af81",
        "subnet-40895a0d"
      ],
      "security_group_ids": [
        "sg-0c0a0065"
      ],
      "route_table_ids": [],
      "private_dns_enabled": false,
      "policy": "{\n  \"Statement\": [\n    {\n      \"Action\": \"*\", \n      \"Effect\": \"Allow\", \n      \"Principal\": \"*\", \n      \"Resource\": \"*\"\n    }\n  ]\n}",
      "tags": {}
    },
    "vpce-0bd867c875b75c7a3": {
      "vpc_id": "vpc-d2a9d9bb",
      "service_name": "com.amazonaws.vpce.us-east-2.vpce-svc-094483e3c0e40c03b",
      "vpc_endpoint_type": "Interface",
      "subnet_ids": [
        "subnet-40895a0d",
        "subnet-47cb8d2e"
      ],
      "security_group_ids": [
        "sg-0c0a0065"
      ],
      "route_table_ids": [],
      "private_dns_enabled": false,
      "policy": "{\n  \"Statement\": [\n    {\n      \"Action\": \"*\", \n      \"Effect\": \"Allow\", \n      \"Principal\": \"*\", \n      \"Resource\": \"*\"\n    }\n  ]\n}",
      "tags": {}
    }
  },
  "flow_logs": {},
  "security_groups": {
    "sg-070322ceb3fe42ccd": {
      "name": "GuardDutyManagedSecurityGroup-vpc-d2a9d9bb",
      "description": "Associated with VPC-vpc-d2a9d9bb and tagged as GuardDutyManaged",
      "vpc_id": "vpc-d2a9d9bb",
      "tags": {}
    },
    "sg-0900022cbfa9e2a96": {
      "name": "rds-launch-wizard",
      "description": "Created from the RDS Management Console: 2018/12/15 21:14:52",
      "vpc_id": "vpc-d2a9d9bb",
      "tags": {}
    },
    "sg-07014b78205cb6171": {
      "name": "launch-wizard-3",
      "description": "launch-wizard-3 created 2024-01-02T09:36:13.308Z",
      "vpc_id": "vpc-d2a9d9bb",
      "tags": {}
    },
    "sg-030eae6ae87c0c6cc": {
      "name": "launch-wizard-2",
      "description": "launch-wizard-2 created 2024-01-02T09:25:21.397Z",
      "vpc_id": "vpc-d2a9d9bb",
      "tags": {}
    },
    "sg-046ca9a7beb55e46a": {
      "name": "navigator-sg",
      "description": "Navigator access rules",
      "vpc_id": "vpc-d2a9d9bb",
      "tags": {}
    },
    "sg-0691bc38f9ee8840b": {
      "name": "Amazon-QuickSight-access",
      "description": "Amazon-QuickSight-access",
      "vpc_id": "vpc-d2a9d9bb",
      "tags": {}
    },
    "sg-02c36eff20c04d9b7": {
      "name": "gittyHome",
      "description": "Allows connection from developer home",
      "vpc_id": "vpc-d2a9d9bb",
      "tags": {}
    },
    "sg-00a1abc08cd804a5d": {
      "name": "launch-wizard-1",
      "description": "launch-wizard-1 created 2022-09-14T06:06:59.867Z",
      "vpc_id": "vpc-d2a9d9bb",
      "tags": {}
    },
    "sg-0339fec4c6ab464a3": {
      "name": "brainswayLambda",
      "description": "brainsway lambda code",
      "vpc_id": "vpc-d2a9d9bb",
      "tags": {}
    },
    "sg-0c0a0065": {
      "name": "default",
      "description": "default VPC security group",
      "vpc_id": "vpc-d2a9d9bb",
      "tags": {}
    }
  }
}
