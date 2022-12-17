provider "aws" {
  profile = var.profile
  region  = var.region
}

terraform {
  required_providers {
    local = {
      version = "~> 2.1"
    }
  }
}

resource "aws_vpc" "aws_asg_and_lb_vpc" {
  cidr_block = "10.0.0.0/24"
  tags = {
    "Name" = "asg_and_lb_vpc_aws"
  }
}

resource "aws_subnet" "subnet-1" {
  vpc_id            = aws_vpc.aws_asg_and_lb_vpc.id
  cidr_block        = "10.0.0.0/26"
  availability_zone = "us-east-1a"
  tags = {
    "Name" = "Subnet-1"
  }
}

resource "aws_subnet" "subnet-2" {
  vpc_id            = aws_vpc.aws_asg_and_lb_vpc.id
  cidr_block        = "10.0.0.64/26"
  availability_zone = "us-east-1b"
  tags = {
    "Name" = "Subnet-2"
  }
}

resource "aws_internet_gateway" "vpc_igw" {
  vpc_id = aws_vpc.aws_asg_and_lb_vpc.id
}

resource "aws_network_acl" "nacl-1" {
  vpc_id = aws_vpc.aws_asg_and_lb_vpc.id
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 300
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  egress {
    protocol   = "tcp"
    rule_no    = 300
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }
}

resource "aws_key_pair" "ssh_ec2" {
  key_name   = "ssh_ec2"
  public_key = file("ssh_ec2.pub")
}


resource "aws_launch_configuration" "launch_config_1" {
  name_prefix     = "terraform-aws-asg-"
  key_name        = aws_key_pair.ssh_ec2.key_name
  image_id        = lookup(var.ami_IDs, var.region)
  instance_type   = "t2.micro"
  user_data       = file("script.sh")
  security_groups = [aws_security_group.ec2_allow_http_and_ssh.id]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg_1" {
  min_size                  = 1
  max_size                  = 3
  desired_capacity          = 2
  health_check_grace_period = 100
  health_check_type         = "ELB"
  launch_configuration      = aws_launch_configuration.launch_config_1.name
  vpc_zone_identifier       = [aws_subnet.subnet-1.id, aws_subnet.subnet-2.id]
}

resource "aws_lb" "lb-1" {
  name               = "asg-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_allow_http.id]
  subnets            = [aws_subnet.subnet-1.id, aws_subnet.subnet-2.id]
}

resource "aws_lb_listener" "lb-1_listener" {
  load_balancer_arn = aws_lb.lb-1.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb-1_target-group.arn
  }

}

resource "aws_lb_target_group" "lb-1_target-group" {
  name     = "asg-lb-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.aws_asg_and_lb_vpc.id
}

resource "aws_autoscaling_attachment" "attach_tg_to_lb" {
  autoscaling_group_name = aws_autoscaling_group.asg_1.id
  lb_target_group_arn    = aws_lb_target_group.lb-1_target-group.arn
}


resource "aws_security_group" "ec2_allow_http_and_ssh" {

  name        = "allow_http_and_ssh"
  description = "allow http and ssh inbound"
  vpc_id      = aws_vpc.aws_asg_and_lb_vpc.id
  egress {
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "allow all outbound"
    from_port        = 0
    ipv6_cidr_blocks = ["::/0"]
    protocol         = "-1"
    to_port          = 0
  }
}

resource "aws_security_group_rule" "ingress_rules" {
  count = length(var.sg_ingress_rules)

  type              = "ingress"
  from_port         = var.sg_ingress_rules[count.index].from_port
  to_port           = var.sg_ingress_rules[count.index].to_port
  protocol          = var.sg_ingress_rules[count.index].protocol
  cidr_blocks       = [var.sg_ingress_rules[count.index].cidr_block]
  description       = var.sg_ingress_rules[count.index].description
  security_group_id = aws_security_group.ec2_allow_http_and_ssh.id
}

resource "aws_security_group" "lb_allow_http" {

  name        = "lb_allow_http"
  description = "allow http inbound"
  vpc_id      = aws_vpc.aws_asg_and_lb_vpc.id
  ingress {
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "allow http inbound"
    from_port        = 80
    ipv6_cidr_blocks = ["::/0"]
    protocol         = "tcp"
    to_port          = 80
  }
  egress {
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "allow all outbound"
    from_port        = 0
    ipv6_cidr_blocks = ["::/0"]
    protocol         = "-1"
    to_port          = 0
  }
}

resource "aws_route_table" "rt_1" {
  vpc_id = aws_vpc.aws_asg_and_lb_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpc_igw.id
  }
  tags = {
    Name = "example"
  }
}

resource "aws_route_table_association" "rt_assoc_1" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.rt_1.id
}

resource "aws_route_table_association" "rt_assoc_2" {
  subnet_id      = aws_subnet.subnet-2.id
  route_table_id = aws_route_table.rt_1.id
}


/* output "ec2_instance_public_ip" {
  value = aws_instance.utk_inst_1.public_ip
}

output "ec2_instance_arn" {
  value = aws_instance.utk_inst_1.arn
} */

output "DNS_record_of_lb" {
  value = aws_lb.lb-1.dns_name
}


