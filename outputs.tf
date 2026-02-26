output "project_id" {
  description = "GCP project ID used for this deployment."
  value       = var.project_id
}

output "gke_cluster_name" {
  description = "GKE cluster name hosting Vault."
  value       = google_container_cluster.vault.name
}

output "gke_zone" {
  description = "GKE cluster zone."
  value       = var.zone
}

output "gke_get_credentials_command" {
  description = "Command to configure local kubectl context for this cluster."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.vault.name} --zone ${var.zone} --project ${var.project_id}"
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
  value       = var.vault_release_name
}

output "vault_external_ip" {
  description = "External IP for the Vault LoadBalancer service (lookup via kubectl)."
  value       = ""
}

output "vault_url" {
  description = "Vault API/UI URL (lookup via kubectl)."
  value       = ""
}

output "vault_lb_lookup_command" {
  description = "Command to retrieve current Vault LoadBalancer IP."
  value       = "kubectl -n ${var.kubernetes_namespace} get svc ${var.vault_release_name} -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
}

output "scheduled_scale_down_enabled" {
  description = "Whether off-hours node pool scale down scheduling is enabled."
  value       = var.enable_scheduled_scale_down
}

output "scheduled_scale_down_cron" {
  description = "Cron expression used for nightly node pool scale down."
  value       = var.scheduled_scale_down_cron
}

output "scheduled_scale_up_cron" {
  description = "Cron expression used for morning node pool scale up."
  value       = var.scheduled_scale_up_cron
}
