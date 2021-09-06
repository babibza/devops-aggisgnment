#-------------------------------------------------------------------
# This module builds Prometheus security groups
#-------------------------------------------------------------------

variable vpc_name {}
variable vpc_id {}
variable vpc_cidr {}
variable environment {}
variable cluster_name {}
variable cluster_domain {}

#-------------------------------------------------------------------
# Jump Host(s): XBI-SANDBOX
# prometheus-jmp-ae01.dev.metrics.internal
#-------------------------------------------------------------------
variable "dev_jumphosts" {
  default = [
    "172.31.57.238/32"
  ]
}

#-------------------------------------------------------------------
# Jump Host(s): XBI-PROD
# Includes XBI EC2 jump hosts and Comcast internal choke points
#-------------------------------------------------------------------
variable "prod_jumphosts" {
  default = [
    "10.54.11.203/32",
    "10.54.35.207/32",
    "172.20.151.135/32",
    "172.20.151.136/32",
    "172.20.255.61/32",
    "172.20.255.65/32",
    "172.20.255.66/32",
    "96.114.221.248/32",
    "96.114.222.55/32",
    "96.115.200.239/32"
  ]
}

#-------------------------------------------------------------------
# Access from Comcast Enterprise RED ZONE systems
# Reference: http://ipctls-ch2-a1p.sys.comcast.net/addrtool/reference_pages/infrastructure_aggs.txt?type=text
#-------------------------------------------------------------------
variable "comcast_enterprise" {
  default = [
    "10.0.0.0/8",
    "172.16.0.0/12",

    "100.96.0.0/11",
    "103.72.193.0/24",
    "147.191.0.0/16",
    "162.149.0.0/16",
    "165.137.0.0/16",
    "169.152.0.0/16",
    "198.137.252.0/23",
    "198.178.8.0/21",
    "24.40.0.0/18",
    "24.40.64.0/20"
  ]
}

#-------------------------------------------------------------------
# Access from Comcast OpenStack (currently unused)
# Reference: https://wiki.sys.comcast.net/pages/viewpage.action?spaceKey=OEC&title=Cloud+Networking+Information
#-------------------------------------------------------------------
variable "comcast_openstack" {
  default = [
    "96.118.0.0/15",
    "96.112.0.0/19",
    "96.115.224.0/20"
  ]
}

#-------------------------------------------------------------------
# Route53 Health Check IPs
#-------------------------------------------------------------------
variable "r53_health_check_ips" {
  default = [
    "54.183.255.128/26",
    "54.241.32.64/26",
    "54.243.31.192/26",
    "54.244.52.192/26",
    "54.245.168.0/26",
    "107.23.255.0/26"
  ]
}

#-------------------------------------------------------------------
# All Production VPCs in the XBI-PROD account
#-------------------------------------------------------------------
variable "prod_vpcs" {
  default = [
    "96.114.221.128/25",
    "96.114.222.0/25",
    "96.115.200.0/22",
    "96.115.204.0/22"
  ]
}

#-------------------------------------------------------------------
# jumphost vpc to security group mapping
#-------------------------------------------------------------------
variable "vpc_jumphost_map" {
  type = "map"
  description = "vpc_name to jumphosts map"
  default = {
    xbi-sandbox = "dev_jumphosts"
    xbi-prod-staging-east = "prod_jumphosts"
    xbi-prod-staging-west = "prod_jumphosts"
    xbi-prod-east = "prod_jumphosts"
    xbi-prod-west = "prod_jumphosts"
  }
}

#-------------------------------------------------------------------
# default vpc security group
# allows Prometheus server to communicate with all ec2
# instances in the VPC where it is deployed to scrape metrics
#-------------------------------------------------------------------
data "aws_security_group" "vpc_default" {
  name = "default"
  vpc_id = "${var.vpc_id}"
}

#-------------------------------------------------------------------
# prometheus jumphost security group
#-------------------------------------------------------------------
resource "aws_security_group" "jumphost" {
  name   = "prometheus-jumphost-${var.cluster_name}-${var.vpc_id}"
  vpc_id = "${var.vpc_id}"
  description = "Ingress to Prometheus cluster nodes on port 22 from jumphosts"

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["${split(" ", var.cluster_domain == "metrics.r53.deap.tv" ? join(" ", var.prod_jumphosts) : join(" ", var.dev_jumphosts))}"]
  }

  tags {
    Name = "prometheus-jumphost-${var.cluster_name}-${var.vpc_id}"
  }
}

#-------------------------------------------------------------------
# default prometheus cluster security group
#-------------------------------------------------------------------
resource "aws_security_group" "prometheus_default" {
  name   = "prometheus-default-${var.cluster_name}-${var.vpc_id}"
  vpc_id = "${var.vpc_id}"
  description = "Ingress for all traffic between Prometheus cluster nodes, allow all outbound traffic"

  ingress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    self        = true
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "prometheus-default-${var.cluster_name}-${var.vpc_id}"
  }
}

#-------------------------------------------------------------------
# prometheus instance
#-------------------------------------------------------------------
resource "aws_security_group" "prometheus" {
  name   = "prometheus-prometheus-${var.cluster_name}-${var.vpc_id}"
  vpc_id = "${var.vpc_id}"
  description = "Ingress on port 9090 for web traffic and r53 health checks"

  ingress {
    protocol    = "tcp"
    from_port   = 9090
    to_port     = 9090
    cidr_blocks = ["${var.comcast_enterprise}"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 9090
    to_port     = 9090
    cidr_blocks = ["${split(" ", var.cluster_domain == "metrics.r53.deap.tv" ? join(" ", var.prod_vpcs) : var.vpc_cidr)}"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 9090
    to_port     = 9090
    cidr_blocks = ["${var.r53_health_check_ips}"]
  }

  tags {
    Name = "prometheus-prometheus-${var.cluster_name}-${var.vpc_id}"
  }
}

#-------------------------------------------------------------------
# alertmanager instance
#-------------------------------------------------------------------
resource "aws_security_group" "alertmanager" {
  name   = "prometheus-alertmanager-${var.cluster_name}-${var.vpc_id}"
  vpc_id = "${var.vpc_id}"
  description = "Ingress on port 9093 for web traffic"

  ingress {
    protocol    = "tcp"
    from_port   = 9093
    to_port     = 9093
    cidr_blocks = [ "${var.comcast_enterprise}" ]
  }

  tags {
    Name = "prometheus-alertmanager-${var.cluster_name}-${var.vpc_id}"
  }
}

#-------------------------------------------------------------------
# pushgateway instance
#-------------------------------------------------------------------
resource "aws_security_group" "pushgateway" {
  name   = "prometheus-pushgateway-${var.cluster_name}-${var.vpc_id}"
  vpc_id = "${var.vpc_id}"
  description = "Ingress on port 9091 for web and vpc traffic"

  ingress {
    protocol    = "tcp"
    from_port   = 9091
    to_port     = 9091
    cidr_blocks = [ "${var.vpc_cidr}" ]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 9091
    to_port     = 9091
    cidr_blocks = [ "${var.comcast_enterprise}" ]
  }

  tags {
    Name = "prometheus-pushgateway-${var.cluster_name}-${var.vpc_id}"
  }
}

#-------------------------------------------------------------------
# cloudwatchexporter
#-------------------------------------------------------------------
resource "aws_security_group" "cloudwatchexporter" {
  name   = "prometheus-cloudwatchexporter-${var.cluster_name}-${var.vpc_id}"
  vpc_id = "${var.vpc_id}"
  description = "Security group for Prometheus cloudwatchexporter"
  #description = "Enables inbound web access on port 9096"

  ingress {
      from_port   = 9106
      to_port     = 9106
      protocol    = "tcp"
      cidr_blocks = [ "${var.vpc_cidr}" ]
  }

  ingress {
      from_port   = 9106
      to_port     = 9106
      protocol    = "tcp"
      cidr_blocks = [ "${var.comcast_enterprise}" ]
  }

  tags {
    Name = "prometheus-cloudwatchexporter-${var.cluster_name}-${var.vpc_id}"
  }
}

#-------------------------------------------------------------------
# grafana instance
#-------------------------------------------------------------------
resource "aws_security_group" "grafana" {
  name   = "prometheus-grafana-${var.cluster_name}-${var.vpc_id}"
  vpc_id = "${var.vpc_id}"
  description = "Ingress on ports 80/3000 for Grafana web access"

  # grafana on port 80
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["${var.comcast_enterprise}"]
  }

  # grafana default port
  ingress {
    protocol    = "tcp"
    from_port   = 3000
    to_port     = 3000
    cidr_blocks = ["${var.comcast_enterprise}"]
  }

  tags {
    Name = "prometheus-grafana-${var.cluster_name}-${var.vpc_id}"
  }
}

output "security_groups" {
  value = {
    "prometheus" = [
      "${data.aws_security_group.vpc_default.id}",
      "${aws_security_group.jumphost.id}",
      "${aws_security_group.prometheus_default.id}",
      "${aws_security_group.prometheus.id}",
      "${aws_security_group.alertmanager.id}"
    ]
    "pushgateway" = [
      "${aws_security_group.jumphost.id}",
      "${aws_security_group.prometheus_default.id}",
      "${aws_security_group.pushgateway.id}"
    ]
    "cloudwatchexporter" = [
      "${aws_security_group.jumphost.id}",
      "${aws_security_group.prometheus_default.id}",
      "${aws_security_group.cloudwatchexporter.id}"
    ]
    "grafana" = [
      "${aws_security_group.jumphost.id}",
      "${aws_security_group.prometheus_default.id}",
      "${aws_security_group.grafana.id}"
    ]
  }
}
