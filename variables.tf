// List of subnets ids to spare the different rabbitmq nodes
variable "subnet_ids" {
  type = "list"
}

// The chosen availability zones *must* match the AZs the VPC subnets are tied to.
variable "availability_zones" {
  type = "list"
}

// Desired number of nodes for autoscaling
variable "rabbitmq_desired_nodes" {
  type    = "string"
  default = "1"
}

// Min number of nodes for autoscaling
variable "rabbitmq_min_nodes" {
  type    = "string"
  default = "1"
}

// Max number of nodes for autoscaling
variable "rabbitmq_max_nodes" {
  type    = "string"
  default = "5"
}

// AWS EC2 instance type for the instances
variable "rabbitmq_instance_type" {
  type    = "string"
  default = "t2.small"
}

// AWS Key pair name
variable "aws_keypair_name" {
  type = "string"
}

// Environment name, used as prefix to name resources
variable "environment" {}

// List of additional cidrs block that will be granted to access the rabbitmq Admin console
// VPC's cidr_block is always granted.
variable "rabbitmq_admin_elb_allow_cidr_blocks" {
  type    = "list"
  default = []
}

// List of additional cidrs block that will be granted to access the rabbitmq broker ELB
// VPC's cidr_block is always granted.
variable "rabbitmq_elb_allow_cidr_blocks" {
  type    = "list"
  default = []
}

// List of additional cidrs block that will be granted to access the rabbitmq isntances (ssh, rabbit ports)
// VPC's cidr_block is always granted.
variable "rabbitmq_instance_allowed_cidr_blocks" {
  type    = "list"
  default = []
}

// Determines if the ELB to be created will be private
variable "rabbitmq_elb_private" {
  default = true
}

// Dns record that will be created if route53_zone_id is provided
// The Dns record will be created as {rabbitmq_dns_name}.{route_zone_name} and it will
// be a CNAME to the rabbitmq ELB.
variable "rabbitmq_dns_name" {
  default = "rabbitmq"
}

// Route53 zone id to create a dns record for rabbitmq.
// The record will be created if and only if this value is provided (non-empty)
variable "route53_zone_id" {
  default = ""
}
