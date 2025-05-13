output "k3s_master_ip" {
  value = aws_instance.k3s_master.public_ip
  description = "Public IP of the K3s master node to be used for SSH and kubeconfig setup"
}