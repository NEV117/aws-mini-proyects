locals {
  common_tags = merge(
    {
      Project   = "macos-ec2"
      ManagedBy = "terraform"
    },
    var.tags,
  )

  # The existing host's AZ, else the AZ set explicitly, else the region's second AZ
  availability_zone = coalesce(
    one(data.aws_ec2_host.existing[*].availability_zone),
    var.availability_zone,
    data.aws_availability_zones.available.names[1],
  )

  host_id = coalesce(var.host_id, one(aws_ec2_host.mac[*].id))

  subnet_id = coalesce(var.subnet_id, one(data.aws_subnet.default[*].id))
}
