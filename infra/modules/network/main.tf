terraform {
  required_providers { aws = { source = "hashicorp/aws", version = ">= 5.0" } }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc.cidr_block
  enable_dns_support   = try(var.vpc.enable_dns_support, true)
  enable_dns_hostnames = try(var.vpc.enable_dns_hostnames, true)
  tags = merge({ Name = "core-vpc" }, try(var.vpc.tags, {}))
}

resource "aws_subnet" "this" {
  for_each                  = var.subnets
  vpc_id                    = each.value.vpc_id
  cidr_block                = each.value.cidr_block
  availability_zone         = try(each.value.availability_zone, null)
  map_public_ip_on_launch   = try(each.value.map_public_ip_on_launch, null)
  tags = try(each.value.tags, {})
}

resource "aws_internet_gateway" "this" {
  for_each = { for id in var.internet_gateways : id => id }
  vpc_id   = aws_vpc.this.id
  tags     = { Name = "igw-${each.key}" }
}

resource "aws_route_table" "this" {
  for_each = var.route_tables
  vpc_id   = each.value.vpc_id
  tags     = try(each.value.tags, {})
}

resource "aws_nat_gateway" "this" {
  for_each      = var.nat_gateways
  subnet_id     = each.value.subnet_id
  allocation_id = each.value.allocation_id
  tags          = try(each.value.tags, {})
}

resource "aws_vpc_endpoint" "this" {
  for_each            = var.vpc_endpoints
  vpc_id              = each.value.vpc_id
  service_name        = each.value.service_name
  vpc_endpoint_type   = each.value.vpc_endpoint_type
  subnet_ids          = try(each.value.subnet_ids, null)
  security_group_ids  = try(each.value.security_group_ids, null)
  route_table_ids     = try(each.value.route_table_ids, null)
  private_dns_enabled = try(each.value.private_dns_enabled, null)
  policy              = try(each.value.policy, null)
  tags                = try(each.value.tags, {})
}

resource "aws_flow_log" "this" {
  for_each        = var.flow_logs
  iam_role_arn    = null
  log_destination = try(each.value.log_destination, null)
  traffic_type    = try(each.value.traffic_type, "ALL")
  vpc_id          = aws_vpc.this.id
}

resource "aws_security_group" "this" {
  for_each    = var.security_groups
  name        = each.value.name
  description = each.value.description
  vpc_id      = each.value.vpc_id
  tags        = try(each.value.tags, {})
  # IMPORTANT: We don't manage rules yet in import phase.
  lifecycle { ignore_changes = [ingress, egress, description, name, tags] }
}
