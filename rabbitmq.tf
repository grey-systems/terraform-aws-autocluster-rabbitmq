data "aws_ami" "rabbit_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-20160114.5"]
  }

  owners = ["099720109477"]
}

data "aws_subnet" "subnet_0" {
  id = "${element(var.subnet_ids,0)}"
}

data "aws_vpc" "vpc" {
  id = "${data.aws_subnet.subnet_0.vpc_id}"
}

resource "aws_iam_role" "autoscaling_rabbitmq_role" {
  name = "${var.environment}-rabbitm-autoscale"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
	"Effect": "Allow",
	"Principal": {
          "Service": ["ec2.amazonaws.com"]
        },
	"Action": ["sts:AssumeRole"]
     }]
  }
EOF
}

resource "aws_iam_policy" "autoscale_rabbit_policy" {
  name        = "${var.environment}-rabbit-autoscale-policy"
  path        = "/"
  description = "rabbitmq_autoscale_policy"

  policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Action": [
				"autoscaling:DescribeAutoScalingInstances",
				"ec2:DescribeInstances"
			],
			"Resource": [
				"*"
			]
		}
	]
}
EOF
}

resource "aws_iam_policy_attachment" "autoscale-rabbit-policy" {
  name       = "${var.environment}-autoscale-rabbit-attac"
  roles      = ["${aws_iam_role.autoscaling_rabbitmq_role.name}"]
  policy_arn = "${aws_iam_policy.autoscale_rabbit_policy.arn}"
}

resource "aws_iam_instance_profile" "rabbitmq_auto_scale_profile" {
  name = "${var.environment}-rabbit-profile"
  role = "${aws_iam_role.autoscaling_rabbitmq_role.name}"
}

resource "aws_security_group" "rabbitmq_elb_sg" {
  name        = "${var.environment}-rabbitmq-elb-sg"
  description = "${var.environment} Security group for rabbitmq autoscale elb"
  vpc_id      = "${data.aws_vpc.vpc.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5672
    to_port     = 5672
    protocol    = "tcp"
    cidr_blocks = ["${concat(split(",",data.aws_vpc.vpc.cidr_block), var.rabbitmq_elb_allow_cidr_blocks)}"]
  }

  ingress {
    from_port   = 15672
    to_port     = 15672
    protocol    = "tcp"
    cidr_blocks = ["${concat(split(",",data.aws_vpc.vpc.cidr_block), var.rabbitmq_admin_elb_allow_cidr_blocks)}"]
  }

  # 80 port is proxied for instance port 15672
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${concat(split(",",data.aws_vpc.vpc.cidr_block), var.rabbitmq_admin_elb_allow_cidr_blocks)}"]
  }
}

#security group for instances
resource "aws_security_group" "rabbitmq_sg" {
  name        = "${var.environment}-rabbitmq-instance-sg"
  description = "rabbitmq_sg Security group for instances"
  vpc_id      = "${data.aws_vpc.vpc.id}"

  # main port rabbitmq
  ingress {
    from_port   = 5672
    to_port     = 5672
    protocol    = "tcp"
    cidr_blocks = ["${concat(split(",",data.aws_vpc.vpc.cidr_block), var.rabbitmq_instance_allowed_cidr_blocks)}"]
  }

  # admin console
  ingress {
    from_port   = 15672
    to_port     = 15672
    protocol    = "tcp"
    cidr_blocks = ["${concat(split(",",data.aws_vpc.vpc.cidr_block), var.rabbitmq_instance_allowed_cidr_blocks)}"]
  }

  # ssh
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${concat(split(",",data.aws_vpc.vpc.cidr_block), var.rabbitmq_instance_allowed_cidr_blocks)}"]
  }

  # Port MApper Daemon (epmd) -> reqired for cluster configs
  ingress {
    from_port   = 4369
    to_port     = 4369
    protocol    = "tcp"
    cidr_blocks = ["${concat(split(",",data.aws_vpc.vpc.cidr_block), var.rabbitmq_instance_allowed_cidr_blocks)}"]
  }

  # all outbound traffic allowed
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elb" "rabbitmq_elb" {
  name            = "${var.environment}-rabbit"
  subnets         = ["${var.subnet_ids}"]
  security_groups = ["${aws_security_group.rabbitmq_elb_sg.id}"]
  internal        = "${var.rabbitmq_elb_private}"

  listener {
    instance_port     = 5672
    instance_protocol = "tcp"
    lb_port           = 5672
    lb_protocol       = "tcp"
  }

  listener {
    instance_port     = 15672
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  listener {
    instance_port     = 15672
    instance_protocol = "http"
    lb_port           = 15672
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    target              = "HTTP:15672/"
    interval            = 30
  }

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags {
    Name = "${var.environment}-rabbitmq"
    Env  = "${var.environment}"
  }
}

# route53_dns record for the elb, only if route53_zone_id is provided
resource "aws_route53_record" "rabbitma-dns" {
  count   = "${var.route53_zone_id == "" ? 0 : 1}"
  zone_id = "${var.route53_zone_id}"
  name    = "${var.rabbitmq_dns_name}"
  type    = "CNMAME"
  ttl     = "300"
  records = ["${aws_elb.rabbitmq_elb.dns_name}"]
}

# user data to install docker & run the image for autoclustering
data "template_file" "rabbitmq_cloud_init" {
  template = <<EOF
#cloud-config
apt_update: true
apt_upgrade: true
apt_sources:
  - source: deb https://apt.dockerproject.org/repo ubuntu-trusty main
    keyid: 58118E89F3A912897C070ADBF76221572C52609D
    filename: docker.list
packages:
  - docker-engine
runcmd:
  - export AWS_DEFAULT_REGION=`ec2metadata --availability-zone | sed s'/.$//'`
  - docker run -d --name rabbitmq --net=host -p 4369:4369 -p 5672:5672 -p 15672:15672 -p 25672:25672 -e AUTOCLUSTER_TYPE=aws -e AWS_AUTOSCALING=true -e AUTOCLUSTER_CLEANUP=true -e CLEANUP_WARN_ONLY=false -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION gavinmroy/alpine-rabbitmq-autocluster:3.6.2-0.6.0
EOF
}

resource "aws_launch_configuration" "rabbit_as_conf" {
  name                 = "${var.environment}_rabbitmq"
  image_id             = "${data.aws_ami.rabbit_ami.id}"
  instance_type        = "${var.rabbitmq_instance_type}"
  iam_instance_profile = "${aws_iam_instance_profile.rabbitmq_auto_scale_profile.id}"
  key_name             = "${var.aws_keypair_name}"
  security_groups      = ["${aws_security_group.rabbitmq_sg.id}"]
  user_data            = "${data.template_file.rabbitmq_cloud_init.rendered}"
}

resource "aws_autoscaling_group" "rabbit_asg" {
  # We want this to explicitly depend on the launch config above
  depends_on = ["aws_launch_configuration.rabbit_as_conf"]
  name       = "${var.environment}-rabbit-asg"

  # The chosen availability zones *must* match the AZs the VPC subnets are tied to.
  availability_zones        = ["${var.availability_zones}"]
  vpc_zone_identifier       = ["${var.subnet_ids}"]
  launch_configuration      = "${aws_launch_configuration.rabbit_as_conf.id}"
  max_size                  = "${var.rabbitmq_max_nodes}"
  min_size                  = "${var.rabbitmq_min_nodes}"
  desired_capacity          = "${var.rabbitmq_desired_nodes}"
  health_check_grace_period = "300"
  health_check_type         = "ELB"
  load_balancers            = ["${aws_elb.rabbitmq_elb.id}"]
}

// Id of the rabbitmq ELB
output "rabbitmq_elb_id" {
  value = "${aws_elb.rabbitmq_elb.id}"
}

// Id of the autoscaling group
output "rabbitmq_autoscaling_group_id" {
  value = "${aws_autoscaling_group.rabbit_asg.id}"
}
