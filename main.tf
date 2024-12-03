provider "aws" {
  region = "us-east-1" # Altere para a região desejada
}

# Obter zonas de disponibilidade disponíveis
data "aws_availability_zones" "available" {}

# Criar uma VPC para o DocumentDB
resource "aws_vpc" "docdb_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Subnets
resource "aws_subnet" "docdb_subnet" {
  count             = 2
  vpc_id            = aws_vpc.docdb_vpc.id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
}

# Security Group
resource "aws_security_group" "docdb_sg" {
  vpc_id = aws_vpc.docdb_vpc.id

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Alterar para um IP mais restrito
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Subnet Group para DocumentDB
resource "aws_docdb_subnet_group" "docdb_subnet_group" {
  name       = "fiap-docdb-subnet-group"
  subnet_ids = aws_subnet.docdb_subnet[*].id
}


resource "aws_docdb_cluster" "docdb_cluster" {
  cluster_identifier      = "fiap-docdb-cluster"
  engine                  = "docdb"
  master_username         = "fiap"
  master_password         = "fiappassword123"
  vpc_security_group_ids  = [aws_security_group.docdb_sg.id]
  backup_retention_period = 1
  preferred_backup_window = "07:00-09:00"
  db_subnet_group_name    = aws_docdb_subnet_group.docdb_subnet_group.name
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.docdb_params.name
  final_snapshot_identifier = "fiap-docdb-cluster-final-snapshot"
}


# Criação de um Cluster Parameter Group para DocumentDB
resource "aws_docdb_cluster_parameter_group" "docdb_params" {
  name   = "custom-docdb-params"
  family = "docdb5.0"

  parameter {
    name  = "tls"
    value = "disabled"
  }
}


# DocumentDB Cluster Instance
resource "aws_docdb_cluster_instance" "docdb_instance" {
  count              = 1
  identifier         = "fiap-docdb-instance-${count.index}"
  cluster_identifier = aws_docdb_cluster.docdb_cluster.id
  instance_class     = "db.t3.medium" # Tipo mais econômico
}
