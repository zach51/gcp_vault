output "project_id" {
  description = "GCP project ID used for this deployment."
  value       = var.project_id
}

output "gke_cluster_name" {
  description = "GKE cluster name hosting Vault."
  value       = google_container_cluster.vault.name
}

output "gke_region" {
  description = "GKE cluster region."
  value       = var.region
}

output "gke_get_credentials_command" {
  description = "Command to configure local kubectl context for this cluster."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.vault.name} --region ${var.region} --project ${var.project_id}"
}

output "vault_namespace" {
  description = "Kubernetes namespace where Vault is deployed."
  value       = var.kubernetes_namespace
}

output "vault_release_name" {
  description = "Vault Helm release name."
  value       = helm_release.vault.name
}

output "vault_service_name" {
  description = "Kubernetes service name for Vault API/UI."
  value       = data.kubernetes_service.vault.metadata[0].name
}

output "vault_external_ip" {
  description = "External IP for the Vault LoadBalancer service (empty until assigned)."
  value       = try(data.kubernetes_service.vault.status[0].load_balancer[0].ingress[0].ip, "")
}

output "vault_url" {
  description = "Vault API/UI URL (may be empty until service IP assignment finishes)."
  value       = try("http://${data.kubernetes_service.vault.status[0].load_balancer[0].ingress[0].ip}:8200", "")
}
