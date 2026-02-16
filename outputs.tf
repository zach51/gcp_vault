output "vault_public_ip" {
  description = "Public IP address for the Vault test VM."
  value       = google_compute_address.vault_public_ip.address
}

output "vault_url" {
  description = "Vault API/UI URL."
  value       = "http://${google_compute_address.vault_public_ip.address}:8200"
}

output "vault_ssh_command" {
  description = "SSH command to access the Vault VM."
  value       = "gcloud compute ssh ${google_compute_instance.vault.name} --zone ${var.zone} --project ${var.project_id}"
}

output "cloudsql_instance_name" {
  description = "Cloud SQL instance name for Vault integration testing."
  value       = try(google_sql_database_instance.cloudsql[0].name, "")
}

output "cloudsql_public_ip" {
  description = "Cloud SQL public IP address (empty if integration is disabled)."
  value       = try(google_sql_database_instance.cloudsql[0].public_ip_address, "")
}

output "cloudsql_database_name" {
  description = "Cloud SQL database name used in integration tests."
  value       = var.cloudsql_database_name
}

output "cloudsql_admin_username" {
  description = "Cloud SQL admin username used by Vault database plugin."
  value       = var.cloudsql_admin_username
}

output "cloudsql_admin_password" {
  description = "Cloud SQL admin password used by Vault database plugin."
  value       = try(random_password.cloudsql_admin[0].result, "")
  sensitive   = true
}
