# terraform-aws-autocluster-rabbitmq

This repo contains a [Terraform](https://terraform.io/) module to provision a rabbitmq cluster using docker, and autoscaling groups of AWS.


Enabled rabbitmq plugins
---------------

- Autocluster
- Consistent Hash Exchange
- Delayed Message Exchange
- Federation
- Federation Management
- Management
- Management Visualiser
- Message Timestamp
- MQTT
- Recent History Exchange
- Sharding
- Shovel
- Shovel Management
- Stomp
- Top
- WebStomp

What is included in this module
------------------------------
* Creation and provisioning of the rabbitmq cluster's nodes using docker image gavinmroy/alpine-rabbitmq-autocluster which supports the autocluster plugin of rabbitmq using aws autoscale groups
* Creation of autoscale group/ launch configurations (and the iam roles/policies required)
* ELB to access rabbitmq 5672 port and the admin console (thourgh port 80 and 15672)
* Posibility to setup the ELB to be internet-faced but it will be created private by default.
* Security groups for the ELB/instances -> by default, traffic is allowed from within inside the VPC CIDR blocks


Requirements
--------------
* VPC is required (see [terraform-multitier-vpc](https://github.com/grey-systems/terraform-multitier-vpc) to create an enabled HA vpc in AWS

Usage
--------
Module usage:

      provider "aws" {
        access_key = "${var.access_key}"
        secret_key = "${var.secret_key}"
        region     = "${var.region}"
      }

    # minimal setup, check Inputs to see the different customisation options
     module "rabbitmq" {
         source                                = "/Users/jmfelguera/Documents/repos/greysystems-github/terraform-aws-rabbitmq"
         subnet_ids                            = "${var.subnet_ids}"
         availability_zones                    = "${var.availability_zones}"
         aws_keypair_name                      = "${var.aws_keypair_name}"
         environment                           = "${var.environment}"
  }


Inputs
---------
| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| availability_zones | The chosen availability zones *must* match the AZs the VPC subnets are tied to. | list | - | yes |
| aws_keypair_name | AWS Key pair name | string | - | yes |
| environment | Environment name, used as prefix to name resources | string | - | yes |
| rabbitmq_admin_elb_allow_cidr_blocks | List of additional cidrs block that will be granted to access the rabbitmq Admin console VPC's cidr_block is always granted. | list | `<list>` | no |
| rabbitmq_desired_nodes | Desired number of nodes for autoscaling | string | `1` | no |
| rabbitmq_dns_name | Dns record that will be created if route53_zone_id is provided The Dns record will be created as {rabbitmq_dns_name}.{route_zone_name} and it will be a CNAME to the rabbitmq ELB. | string | `rabbitmq` | no |
| rabbitmq_elb_allow_cidr_blocks | List of additional cidrs block that will be granted to access the rabbitmq broker ELB VPC's cidr_block is always granted. | list | `<list>` | no |
| rabbitmq_elb_private | Determines if the ELB to be created will be private | string | `true` | no |
| rabbitmq_instance_allowed_cidr_blocks | List of additional cidrs block that will be granted to access the rabbitmq isntances (ssh, rabbit ports) VPC's cidr_block is always granted. | list | `<list>` | no |
| rabbitmq_instance_type | AWS EC2 instance type for the instances | string | `t2.small` | no |
| rabbitmq_max_nodes | Max number of nodes for autoscaling | string | `5` | no |
| rabbitmq_min_nodes | Min number of nodes for autoscaling | string | `1` | no |
| route53_zone_id | Route53 zone id to create a dns record for rabbitmq. The record will be created if and only if this value is provided (non-empty) | string | `` | no |
| subnet_ids | List of subnets ids to spare the different rabbitmq nodes | list | - | yes |

Outputs
---------

| Name | Description |
|------|-------------|
| rabbitmq_autoscaling_group_id | Id of the autoscaling group |
| rabbitmq_elb_id | Id of the rabbitmq ELB |

Contributing
------------
Everybody is welcome to contribute. Please, see [`CONTRIBUTING`][contrib] for further information.

[contrib]: CONTRIBUTING.md

Bug Reports
-----------

Bug reports can be sent directly to authors and/or using github's issues.


-------

Copyright (c) 2017 Grey Systems ([www.greysystems.eu](http://www.greysystems.eu))

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
