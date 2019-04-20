output "HAProxy nodes private IPs" {
  value = "${aws_instance.haproxy_node.*.private_ip}"
}

output "HAProxy node EIP1 (primary interface) allocation IDs" {
  value = "${aws_eip.haproxy_node_eip1.*.id}"
}

output "HAProxy node EIP1 (primary interface) public IPs" {
  value = "${aws_eip.haproxy_node_eip1.*.public_ip}"
}

output "HAProxy node primary interface IDs" {
  value = "${aws_instance.haproxy_node.*.primary_network_interface_id}"
}

output "Web node private IPs" {
  value = "${aws_instance.web_node.*.private_ip}"
}

output "Web node public IPs" {
  value = "${aws_instance.web_node.*.public_ip}"
}
