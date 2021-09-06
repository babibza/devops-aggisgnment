variable environment { }
variable aws_region {  }
variable aws_key_name { }
variable vpc_name { }
variable iam_instance_profile { }
variable sns_topic { }
variable cluster_prefix { }
variable cluster_name { }
variable cluster_domain { }

variable prometheus_instance_type { }
variable prometheus_instance_termination_protection { }
variable prometheus_ebs_volume_type { }
variable prometheus_ebs_volume_size { }
variable prometheus_ebs_volume_iops { }

variable grafana_instance_type { }
variable grafana_instance_termination_protection { }

variable pushgateway_instance_type { }
variable pushgateway_instance_termination_protection { }

variable cloudwatchexporter_instance_type { }
variable cloudwatchexporter_instance_termination_protection { }

provider "aws" {
  region = "${var.aws_region}"
}

module "config" {
  source = "../config"
  vpc_name = "${var.vpc_name}"
}

module "security_groups" {
  source = "../security_groups"
  vpc_name      = "${var.vpc_name}"
  vpc_id        = "${module.config.vpc_id}"
  vpc_cidr      = "${module.config.vpc_cidr}"
  environment   = "${var.environment}"
  cluster_name  = "${var.cluster_name}"
  cluster_domain = "${var.cluster_domain}"
}

module "prometheus" {
  source = "../prometheus"
  aws_key_name        = "${var.aws_key_name}"
  aws_region          = "${var.aws_region}"
  environment         = "${var.environment}"
  aws_account_id      = "${module.config.aws_account_id}"
  vpc_id              = "${module.config.vpc_id}"
  region_id           = "${module.config.region_id}"
  dns_zone_id         = "${module.config.dns_zone_id}"
  ami_id              = "${module.config.ami_id}"
  iam_instance_profile= "${var.iam_instance_profile}"
  sns_topic           = "${var.sns_topic}"
  cluster_prefix      = "${var.cluster_prefix}"
  cluster_name        = "${var.cluster_name}"
  cluster_domain      = "${var.cluster_domain}"
  subnet_ids          = "${module.config.vpc_subnet_ids}"
  availability_zones  = "${module.config.vpc_availability_zones}"
  security_groups     = "${module.security_groups.security_groups["prometheus"]}"
  instance_type             = "${var.prometheus_instance_type}"
  termination_protection    = "${var.prometheus_instance_termination_protection}"
  ebs_volume_type           = "${var.prometheus_ebs_volume_type}"
  ebs_volume_size           = "${var.prometheus_ebs_volume_size}"
  ebs_volume_iops           = "${var.prometheus_ebs_volume_iops}"
}

module "grafana" {
  source = "../grafana"
  aws_key_name        = "${var.aws_key_name}"
  aws_region          = "${var.aws_region}"
  environment         = "${var.environment}"
  aws_account_id      = "${module.config.aws_account_id}"
  vpc_id              = "${module.config.vpc_id}"
  region_id           = "${module.config.region_id}"
  dns_zone_id         = "${module.config.dns_zone_id}"
  ami_id              = "${module.config.ami_id}"
  iam_instance_profile= "${var.iam_instance_profile}"
  sns_topic           = "${var.sns_topic}"
  cluster_prefix      = "${var.cluster_prefix}"
  cluster_name        = "${var.cluster_name}"
  cluster_domain      = "${var.cluster_domain}"
  subnet_ids          = "${module.config.vpc_subnet_ids}"
  availability_zones  = "${module.config.vpc_availability_zones}"
  security_groups     = "${module.security_groups.security_groups["grafana"]}"
  instance_type             = "${var.grafana_instance_type}"
  termination_protection    = "${var.grafana_instance_termination_protection}"
}

module "pushgateway" {
  source = "../pushgateway"
  aws_key_name        = "${var.aws_key_name}"
  aws_region          = "${var.aws_region}"
  environment         = "${var.environment}"
  aws_account_id      = "${module.config.aws_account_id}"
  vpc_id              = "${module.config.vpc_id}"
  region_id           = "${module.config.region_id}"
  dns_zone_id         = "${module.config.dns_zone_id}"
  ami_id              = "${module.config.ami_id}"
  iam_instance_profile= "${var.iam_instance_profile}"
  sns_topic           = "${var.sns_topic}"
  cluster_prefix      = "${var.cluster_prefix}"
  cluster_name        = "${var.cluster_name}"
  cluster_domain      = "${var.cluster_domain}"
  subnet_ids          = "${module.config.vpc_subnet_ids}"
  availability_zones  = "${module.config.vpc_availability_zones}"
  security_groups     = "${module.security_groups.security_groups["pushgateway"]}"
  instance_type             = "${var.pushgateway_instance_type}"
  termination_protection    = "${var.pushgateway_instance_termination_protection}"
}

module "cloudwatchexporter" {
  source = "../cloudwatchexporter"
  aws_key_name        = "${var.aws_key_name}"
  aws_region          = "${var.aws_region}"
  environment         = "${var.environment}"
  aws_account_id      = "${module.config.aws_account_id}"
  vpc_id              = "${module.config.vpc_id}"
  region_id           = "${module.config.region_id}"
  dns_zone_id         = "${module.config.dns_zone_id}"
  ami_id              = "${module.config.ami_id}"
  iam_instance_profile= "${var.iam_instance_profile}"
  sns_topic           = "${var.sns_topic}"
  cluster_prefix      = "${var.cluster_prefix}"
  cluster_name        = "${var.cluster_name}"
  cluster_domain      = "${var.cluster_domain}"
  subnet_ids          = "${module.config.vpc_subnet_ids}"
  availability_zones  = "${module.config.vpc_availability_zones}"
  security_groups     = "${module.security_groups.security_groups["cloudwatchexporter"]}"
  instance_type             = "${var.cloudwatchexporter_instance_type}"
  termination_protection    = "${var.cloudwatchexporter_instance_termination_protection}"
}

output "prometheus_vip" {
  value = ["${module.prometheus.vip}"]
}
output "prometheus_hostnames" {
  value = ["${module.prometheus.hostnames}"]
}

output "pushgateway_vip" {
  value = ["${module.pushgateway.vip}"]
}
output "pushgateway_hostnames" {
  value = ["${module.pushgateway.hostnames}"]
}

output "cloudwatchexporter_vip" {
  value = ["${module.cloudwatchexporter.vip}"]
}
output "cloudwatchexporter_hostnames" {
  value = ["${module.cloudwatchexporter.hostnames}"]
}

output "grafana_vip" {
  value = ["${module.grafana.vip}"]
}
output "grafana_hostnames" {
  value = ["${module.grafana.hostnames}"]
}
