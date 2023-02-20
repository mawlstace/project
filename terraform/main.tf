provider "aws" {
  region = "eu-central-1"
}

# Create a VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "my-vpc"
  }
}

# Create a public subnet and route table
resource "aws_subnet" "public_subnet" {
  cidr_block = "10.0.1.0/24"
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "public-subnet"
  }
}

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
}

resource "aws_route_table_association" "public_route_table_association" {
  subnet_id = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# # Create a private subnet and route table
# resource "aws_subnet" "private_subnet" {
#   cidr_block = "10.0.2.0/24"
#   vpc_id = aws_vpc.my_vpc.id
#   tags = {
#     Name = "private-subnet"
#   }
# }

# resource "aws_route_table" "private_route_table" {
#   vpc_id = aws_vpc.my_vpc.id

#   # Route traffic to the internet via NAT Gateway
#   route {
#     cidr_block = "0.0.0.0/0"
#     nat_gateway_id = aws_nat_gateway.my_nat_gateway.id
#   }
# }

# resource "aws_route_table_association" "private_route_table_association" {
#   subnet_id = aws_subnet.private_subnet.id
#   route_table_id = aws_route_table.private_route_table.id
# }

# Create a NAT Gateway in a public subnet
resource "aws_eip" "my_eip" {
  vpc = true
}

resource "aws_nat_gateway" "my_nat_gateway" {
  allocation_id = aws_eip.my_eip.id
  subnet_id = aws_subnet.public_subnet.id
}

# resource "aws_security_group" "private_sg" {
#   name_prefix = "private-sg"
#   vpc_id = aws_vpc.my_vpc.id

#   ingress {
#     from_port = 22
#     to_port = 22
#     protocol = "tcp"
#     cidr_blocks = ["10.0.1.0/24"]
#   }

#   egress {
#     from_port = 0
#     to_port = 0
#     protocol = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

resource "aws_security_group" "public_sg" {
  name_prefix = "public-sg"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}




data "aws_key_pair" "my-key" {
  key_name           = "my-key"
  include_public_key = true
}

data "template_file" "startup" {
 template = file("userdata.sh")
}



resource "aws_instance" "public_instance" {
  ami = "ami-0d1ddd83282187d18"
  instance_type = "t2.medium"
  subnet_id = aws_subnet.public_subnet.id
  iam_instance_profile = aws_iam_instance_profile.ssm_ec2_profile.name
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  associate_public_ip_address = true
  user_data = data.template_file.startup.rendered
  key_name  = data.aws_key_pair.my-key.key_name
  tags = {
    Name = "web_instance"
  }
}

# resource "aws_instance" "web_instance" {
#   ami = "ami-0d1ddd83282187d18"
#   instance_type = "t2.micro"
#   subnet_id = aws_subnet.private_subnet.id
#   iam_instance_profile = aws_iam_instance_profile.ssm_ec2_profile.name
#   user_data = data.template_file.startup.rendered
#   vpc_security_group_ids = [aws_security_group.private_sg.id]
#   key_name  = data.aws_key_pair.my-key.key_name


#   tags = {
#     Name = "web_instance"
#   }
# }





## create ssm_profile , ssm_role and ssm_attachment ## 
resource "aws_iam_instance_profile" "ssm_ec2_profile" {
  name = "ssm-instance-profile"
  role = aws_iam_role.ssm_role.name
}

resource "aws_iam_role" "ssm_role" {
  name = "ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_role_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
  role       = aws_iam_role.ssm_role.name
}

