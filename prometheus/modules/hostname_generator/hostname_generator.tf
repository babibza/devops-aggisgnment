variable "cluster_prefix" {
  type = "string"
}

variable "cluster_component" {
  type = "string"
}

variable "instance_count" {
  type = "string"
  default = "1"
}

variable "region_id" {
  type = "string"
}

variable "cluster_name" {
  type = "string"
}

data "template_file" "hostnames" {
  count = "${var.instance_count}"
  template = "${format("%s-%s%02d-%s-%s", var.cluster_prefix, var.cluster_component, count.index+1, var.region_id, var.cluster_name)}"
}

output "hostnames" {
  value = ["${data.template_file.hostnames.*.rendered}"]
}
