variable "profile" {
  default = "utk-cloud"
}

variable "region" {
  default = "us-east-1"
}

variable "ami_IDs" {
  type = map(any)
  default = {
    "us-east-1" : "ami-08c40ec9ead489470",
    "us-west-2" : "ami-017fecd1353bcc96e",
    "ap-south-1" : "ami-062df10d14676e201"
  }
}

variable "instance_type" {
  default = "t2.micro"
}


variable "private_key_file" {   
  default = "ssh_ec2"
}

variable "sg_ingress_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_block  = string
    description = string
  }))
  default = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_block  = "0.0.0.0/0"
      description = "test"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_block  = "0.0.0.0/0"
      description = "test"
    },
  ]
}



