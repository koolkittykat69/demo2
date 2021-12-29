#output "available_avail_zones" {
#  value = [for name in data.aws_availability_zones.available.names : name]
#}

#output "selected_avail_zones" {
#  value = [for zone in var.avail_zones : zone]
#}

#output "nats_ips" {
#  value = [for nat in aws_eip.eip : nat.public_ip]
#}

output "lb_ip" {
  value = aws_lb.main.dns_name
}
