#-------------------------------------------------------------------
# This module builds Cloudwatch Exporter infrastructure
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
variable cluster_component { default = "cloudwatchexporter" }
variable cluster_name {}
variable cluster_domain {}
variable security_groups { type = "list" }
variable subnet_ids { type = "list" }
variable availability_zones { type = "list" }

variable instance_type { default = "m4.large" }
variable instance_count { default = "1" }
variable termination_protection { default = "false" }
variable ebs_volume_type { default = "gp2" }
variable ebs_volume_size { default = "25" }
variable ebs_delete_on_termination { default = "true" }

module "hostnames" {
  source = "../hostname_generator"
  cluster_prefix = "${var.cluster_prefix}"
  cluster_component = "${var.cluster_component}"
  instance_count = "${var.instance_count}"
  region_id = "${var.region_id}"
  cluster_name = "${var.cluster_name}"
}

resource "aws_instance" "cloudwatchexporter" {
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
resource "aws_route53_record" "cloudwatchexporter" {
  count = "${var.instance_count}"
  zone_id = "${var.dns_zone_id}"
  name = "${module.hostnames.hostnames[count.index]}"
  type = "A"
  ttl = "300"
  records = ["${element(aws_instance.cloudwatchexporter.*.private_ip, count.index)}"]
}

resource "aws_route53_record" "cloudwatchexporter_vip" {
  count = "${var.instance_count}"
  zone_id = "${var.dns_zone_id}"
  name =  "${var.environment == "prod" ? "${var.cluster_component}-${var.region_id}" : "${var.cluster_component}-${var.region_id}-${var.cluster_name}" }"
  type = "A"
  ttl = "60"
  records = ["${element(aws_instance.cloudwatchexporter.*.private_ip, count.index)}"]
}

#-------------------------------------------------------------------
# CloudWatch Alarms
#-------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "cloudwatchexporter_ec2_autorecover" {
  alarm_name          = "${module.hostnames.hostnames[count.index]}-ec2-autorecover"
  count               = "${var.instance_count}"
  namespace           = "AWS/EC2"
  evaluation_periods  = "2"
  period              = "60"
  alarm_description   = "This metric alarm auto recovers Prometheus Cloudwatch Exporter EC2 instances"
  alarm_actions       = [
    "arn:aws:automate:${var.aws_region}:ec2:recover",
    "arn:aws:sns:${var.aws_region}:${var.aws_account_id}:${var.sns_topic}"
  ]
  statistic           = "Maximum"
  comparison_operator = "GreaterThanThreshold"
  threshold           = "1"
  metric_name         = "StatusCheckFailed_System"
  dimensions {
      InstanceId = "${element(aws_instance.cloudwatchexporter.*.id, count.index)}"
  }
}

output "vip" {
  value = ["${element(aws_route53_record.cloudwatchexporter_vip.*.fqdn, 0)}"]
}
output "hostnames" {
  value = ["${aws_route53_record.cloudwatchexporter.*.fqdn}"]
}
output "private_ips" {
  value = ["${aws_instance.cloudwatchexporter.*.private_ip}"]
}
output "instances" {
  value = ["${aws_instance.cloudwatchexporter.*.id}"]
}
output "names" {
  value = ["${aws_instance.cloudwatchexporter.*.tags.Name}"]
}
