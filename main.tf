provider "aws" {
  region = "us-east-1"
  
}

resource "tls_private_key" task1_p_key  {
  algorithm = "RSA"
}


resource "aws_key_pair" "task1-key" {
  key_name    = "task1-key"
  public_key = tls_private_key.task1_p_key.public_key_openssh
  }

resource "local_file" "private_key" {
  depends_on = [
    tls_private_key.task1_p_key,
  ]
  content  = tls_private_key.task1_p_key.private_key_pem
  filename = "webserver.pem"
}

resource "aws_vpc" "gl-vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
 
tags = {
    Name = "gl-vpc"
}
}

resource "aws_subnet" "public_Subnet" {
  vpc_id                  = aws_vpc.gl-vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone       = "us-east-1a"
tags = {
   Name = "public Subnet"
}
}

resource "aws_subnet" "private_subnet2" {
  vpc_id                  = aws_vpc.gl-vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
tags = {
   Name = "private Subnet"
}
}
resource "aws_internet_gateway" "gl-igw" {
 vpc_id = aws_vpc.gl-vpc.id
 tags = {
        Name = "My VPC Internet Gateway"
}
}

resource "aws_route_table" "public-crt" {
 vpc_id = aws_vpc.gl-vpc.id
 tags = {
        Name = "My VPC Route Table"
}
}

resource "aws_route" "gl-vpc_internet_access" {
  route_table_id         = aws_route_table.public-crt.id
  destination_cidr_block =  "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gl-igw.id
}

resource "aws_route_table_association" "gl-vpc_association" {
  subnet_id      = aws_subnet.public_Subnet.id
  route_table_id = aws_route_table.public-crt.id
}

resource "aws_security_group" "only_public_ssh_bositon" {
  depends_on=[aws_subnet.public_Subnet]
  name        = "only_ssh_bositon"
  vpc_id      =  aws_vpc.gl-vpc.id

ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {

    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "only_public_ssh_bastion"
  }
}
resource "aws_instance" "BASTION" {
  ami           = "ami-028384781c3bdd974"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.public_Subnet.id
  vpc_security_group_ids = [ aws_security_group.only_public_ssh_bositon.id ]
  key_name = "task1-key"

  tags = {
    Name = "bastionhost"
    }
}


resource "aws_security_group" "private_sg" {
  name        = "private_sg"
   vpc_id     = aws_vpc.gl-vpc.id

ingress {

    from_port   = 3306		
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  ingress {

    from_port   = 22		
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }
egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_eip" "abhi_ip" {
  domain              = "vpc"
  public_ipv4_pool = "amazon"
}


resource "aws_nat_gateway" "abhingw" {
    depends_on=[aws_eip.abhi_ip]
  allocation_id = aws_eip.abhi_ip.id
  subnet_id     = aws_subnet.public_Subnet.id
tags = {
    Name = "Natgateway"
  }
}

// Route table for SNAT in private subnet

resource "aws_route_table" "private_subnet_route_table" {
      depends_on=[aws_nat_gateway.abhingw]
  vpc_id = aws_vpc.gl-vpc.id


  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.abhingw.id
  }



  tags = {
    Name = "private_subnet_route_table"
  }
}


resource "aws_route_table_association" "private_subnet_route_table_association" {
  depends_on = [aws_route_table.private_subnet_route_table]
  subnet_id      = aws_subnet.private_subnet2.id
  route_table_id = aws_route_table.private_subnet_route_table.id
}



