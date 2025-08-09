terraform { required_providers { aws = { source = "hashicorp/aws", version = ">= 5.0" } } }

resource "aws_instance" "this" {
  for_each                    = var.instances
  ami                         = each.value.ami
  instance_type               = each.value.instance_type
  subnet_id                   = try(each.value.subnet_id, null)
  vpc_security_group_ids      = try(each.value.vpc_security_group_ids, null)
  key_name                    = try(each.value.key_name, null)
  iam_instance_profile        = try(each.value.iam_instance_profile, null)
  associate_public_ip_address = try(each.value.associate_public_ip_address, null)
  tags                        = try(each.value.tags, {})
  lifecycle { ignore_changes = all }
}
