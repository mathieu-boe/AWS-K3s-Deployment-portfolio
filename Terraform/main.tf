/*
-------------------------------------------
Variables (expected in variables.tf)
-------------------------------------------
variable "aws_region"
*/

/*
-------------------------------------------
Virtual Private Cloud
-------------------------------------------
*/

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

/*
-------------------------------------------
Environments Subnet
-------------------------------------------
*/

resource "aws_subnet" "dev" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "dev-subnet"
  }
}

resource "aws_subnet" "prod" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "prod-subnet"
  }
}

/*
-------------------------------------------
Route Table
-------------------------------------------
*/

# Main route table for dev and prod subnets
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "main-route-table"
  }
}

/*
-------------------------------------------
Route Table Association
-------------------------------------------
*/

# Associate dev subnet with the route table
resource "aws_route_table_association" "dev_association" {
  subnet_id      = aws_subnet.dev.id
  route_table_id = aws_route_table.main.id
}

# Associate prod subnet with the route table
resource "aws_route_table_association" "prod_association" {
  subnet_id      = aws_subnet.prod.id
  route_table_id = aws_route_table.main.id
}

/*
-------------------------------------------
Internet Gateway
-------------------------------------------
*/
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

/*
-------------------------------------------
Security Group
-------------------------------------------
*/

resource "aws_security_group" "k3s_sg" {
  name_prefix = "k3s-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port = 80
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
    from_port = 6443
    to_port = 6443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port  = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

/*
-------------------------------------------
SSH Keys
-------------------------------------------
*/

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("~/.ssh/aws-project.pub")
}

/*
-------------------------------------------
EC2 Instances
-------------------------------------------
*/

resource "aws_instance" "k3s_master" {
  ami = "ami-0dfe0f1abee59c78d" # Amazon Linux 2023 EU-WEST-2B
  instance_type = "t2.micro" #t2.micro is not recommended for the Master node (specs are too low), but it's the only one available as Free Tier Eligible on AWS
  key_name = aws_key_pair.deployer.key_name
  subnet_id = aws_subnet.prod.id
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]

  tags = {
    Name = "k3s-master-prod"
  }

  provisioner "remote-exec" {
    inline = [
      "curl -sfL https://get.k3s.io | sh -"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/aws-project")
      host        = self.public_ip
    }
  }
}

resource "null_resource" "get_k3s_token" {
  provisioner "local-exec" {
    command = <<EOT
      ssh -o StrictHostKeyChecking=no -i ~/.ssh/aws-project ec2-user@${aws_instance.k3s_master.public_ip} 'sudo cat /var/lib/rancher/k3s/server/node-token' > k3s_token.txt
    EOT
  }

  depends_on = [aws_instance.k3s_master]
}

resource "aws_instance" "k3s_worker" {
  ami = "ami-0dfe0f1abee59c78d" # Amazon Linux 2023 EU-WEST-2A
  instance_type = "t2.micro"
  key_name = aws_key_pair.deployer.key_name
  subnet_id = aws_subnet.dev.id
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]

  tags = {
    Name = "k3s-worker-dev"
  }

  provisioner "file" {
    source      = "k3s_token.txt"
    destination = "/tmp/k3s_token.txt"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/aws-project")
      host        = self.public_ip
    }
  }

  provisioner "remote-exec" {
  inline = [
    "bash -c 'SERVER_IP=\"https://${aws_instance.k3s_master.private_ip}:6443\" && K3S_TOKEN=$(cat /tmp/k3s_token.txt) && curl -sfL https://get.k3s.io | K3S_URL=$SERVER_IP K3S_TOKEN=$K3S_TOKEN sh -s - agent'"
  ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/aws-project")
      host        = self.public_ip
    }
  }

  depends_on = [
    aws_instance.k3s_master,
    null_resource.get_k3s_token
  ]
}