#-------------------------------------------------------------------
# This module builds Prometheus infrastructure
# - EC2 instances with EBS root volumes
# - Route 53 DNS records and health checks
# - CloudWatch alarms for health check status and ec2 auto recovery
#-------------------------------------------------------------------

variable aws_key_name {}
variable aws_region {}
variable aws_account_id {}
variable environment {}
variable vpc_id {}
variable region_id {}
variable dns_zone_id {}
variable ami_id {}
variable iam_instance_profile {}
variable sns_topic {}
variable cluster_prefix {}
variable cluster_component { default = "prometheus" }
variable cluster_name {}
variable cluster_domain {}
variable security_groups { type = "list" }
variable subnet_ids { type = "list" }
variable availability_zones { type = "list" }

variable instance_type { default = "m4.large" }
variable instance_count { default = "2" }
variable termination_protection { default = "false" }
variable ebs_volume_type { default = "gp2" }
variable ebs_volume_size { default = "100" }
variable ebs_volume_iops { default = "300" }
variable ebs_delete_on_termination { default = "true" }

module "hostnames" {
  source = "../hostname_generator"
  cluster_prefix = "${var.cluster_prefix}"
  cluster_component = "${var.cluster_component}"
  instance_count = "${var.instance_count}"
  region_id = "${var.region_id}"
  cluster_name = "${var.cluster_name}"
}

resource "aws_instance" "prometheus" {
  ami           = "${var.ami_id}"
  count         = "${var.instance_count}"
  instance_type = "${var.instance_type}"
  key_name      = "${var.aws_key_name}"
  subnet_id     = "${element(var.subnet_ids, count.index)}"
  availability_zone  = "${element(var.availability_zones, count.index)}"
  iam_instance_profile = "${var.iam_instance_profile}"
  vpc_security_group_ids = ["${var.security_groups}"]

  ebs_optimized = true
  disable_api_termination = "${var.termination_protection}"

  root_block_device {
   volume_type = "${var.ebs_volume_type}"
   volume_size = "${var.ebs_volume_size}"
   iops = "${var.ebs_volume_iops}"
   delete_on_termination = "${var.ebs_delete_on_termination}"
 }

 lifecycle {
   ignore_changes = ["user_data"]
 }

 tags {
   Name = "${module.hostnames.hostnames[count.index]}.${var.cluster_domain}"
   environment = "${var.environment}"
   region_id = "${var.region_id}"
   cluster_prefix = "${var.cluster_prefix}"
   cluster_name = "${var.cluster_name}"
   cluster_domain = "${var.cluster_domain}"
   vpc = "${var.vpc_id}"
   role = "${var.cluster_component}"
   Platform = "Prometheus"
 }
}

#-------------------------------------------------------------------
# Route53 DNS Records
#-------------------------------------------------------------------
resource "aws_route53_record" "prometheus" {
  count = "${var.instance_count}"
  zone_id = "${var.dns_zone_id}"
  name = "${module.hostnames.hostnames[count.index]}"
  type = "A"
  ttl = "300"
  records = ["${element(aws_instance.prometheus.*.private_ip, count.index)}"]
}

resource "aws_route53_record" "prometheus_vip" {
  count = "${var.instance_count}"
  zone_id = "${var.dns_zone_id}"
  name =  "${var.environment == "prod" ? "${var.cluster_component}-${var.region_id}" : "${var.cluster_component}-${var.region_id}-${var.cluster_name}" }"
  type = "A"
  ttl = "60"
  records = ["${element(aws_instance.prometheus.*.private_ip, count.index)}"]
  set_identifier = "${module.hostnames.hostnames[count.index]}"

  failover_routing_policy {
    type = "${count.index == "0" ? "PRIMARY" : "SECONDARY"}"
  }

  health_check_id = "${element(aws_route53_health_check.prometheus.*.id, count.index)}"
}

#-------------------------------------------------------------------
# Route53 Health Checks
#-------------------------------------------------------------------
resource "aws_route53_health_check" "prometheus" {
  count = "${var.instance_count}"
  ip_address = "${var.cluster_domain == "metrics.r53.deap.tv" ? element(aws_instance.prometheus.*.private_ip, count.index) : element(aws_instance.prometheus.*.public_ip, count.index)}"
  port = 9090
  resource_path = "/status"
  type = "HTTP"
  failure_threshold = "2"
  request_interval = "30"
  tags {
    Name = "${element(aws_route53_record.prometheus.*.fqdn, count.index)}"
    environment = "${var.environment}"
    region_id = "${var.region_id}"
    cluster_prefix = "${var.cluster_prefix}"
    cluster_name = "${var.cluster_name}"
    cluster_domain = "${var.cluster_domain}"
    vpc = "${var.vpc_id}"
    role = "${var.cluster_component}"
    Platform = "Prometheus"
  }
}

resource "null_resource" "r53_healthcheck_provisioner_prometheus" {
  count = "${var.instance_count}"
  triggers {
    health_check_id = "${element(aws_route53_health_check.prometheus.*.id, count.index)}"
  }
  provisioner "local-exec" {
    command = "aws route53 update-health-check --health-check-id ${element(aws_route53_health_check.prometheus.*.id, count.index)} --regions \"us-east-1\" \"us-west-1\" \"us-west-2\" "
  }
}

#-------------------------------------------------------------------
# CloudWatch Alarms
#-------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "prometheus_ec2_autorecover" {
  alarm_name          = "${module.hostnames.hostnames[count.index]}-ec2-autorecover"
  count               = "${var.instance_count}"
  namespace           = "AWS/EC2"
  evaluation_periods  = "2"
  period              = "60"
  alarm_description   = "This metric alarm auto recovers Prometheus EC2 instances"
  alarm_actions       = [
    "arn:aws:automate:${var.aws_region}:ec2:recover",
    "arn:aws:sns:${var.aws_region}:${var.aws_account_id}:${var.sns_topic}"
  ]
  statistic           = "Maximum"
  comparison_operator = "GreaterThanThreshold"
  threshold           = "1"
  metric_name         = "StatusCheckFailed_System"
  dimensions {
      InstanceId = "${element(aws_instance.prometheus.*.id, count.index)}"
  }
}

resource "aws_cloudwatch_metric_alarm" "prometheus_r53_health_check" {
  alarm_name          = "${module.hostnames.hostnames[count.index]}-r53-health-check"
  count               = "${var.instance_count}"
  namespace           = "AWS/Route53"
  metric_name         = "HealthCheckStatus"
  evaluation_periods  = "1"
  period              = "60"
  statistic           = "Minimum"
  comparison_operator = "LessThanThreshold"
  threshold           = "1"
  dimensions {
      HealthCheckId = "${element(aws_route53_health_check.prometheus.*.id, count.index)}"
  }
  alarm_description   = "This metric alarm fires when Route53 health check fails"
  alarm_actions       = [
    "arn:aws:sns:${var.aws_region}:${var.aws_account_id}:${var.sns_topic}"
  ]
}


output "vip" {
  value = ["${element(aws_route53_record.prometheus_vip.*.fqdn, 0)}"]
}
output "hostnames" {
  value = ["${aws_route53_record.prometheus.*.fqdn}"]
}
output "private_ips" {
  value = ["${aws_instance.prometheus.*.private_ip}"]
}
output "instances" {
  value = ["${aws_instance.prometheus.*.id}"]
}
output "names" {
  value = ["${aws_instance.prometheus.*.tags.Name}"]
}
