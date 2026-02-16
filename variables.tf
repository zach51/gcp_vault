variable "project_id" {
  description = "GCP project ID where Vault lab resources will be deployed."
  type        = string
  default     = "zachbeelercloud-dev"
}

variable "region" {
  description = "GCP region for Vault lab resources."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for the Vault VM."
  type        = string
  default     = "us-central1-a"
}

variable "name_prefix" {
  description = "Name prefix applied to all lab resources."
  type        = string
  default     = "vault-lab"
}

variable "machine_type" {
  description = "Machine type for the Vault VM."
  type        = string
  default     = "e2-medium"
}

variable "vault_version" {
  description = "Vault version to install on the VM."
  type        = string
  default     = "1.17.5"
}

variable "admin_cidrs" {
  description = "CIDR ranges allowed to reach SSH and Vault API/UI (8200)."
  type        = list(string)
}

variable "network_cidr" {
  description = "Primary CIDR block for the Vault lab subnet."
  type        = string
  default     = "10.70.0.0/24"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size for the Vault VM."
  type        = number
  default     = 30
}

variable "enable_nightly_shutdown" {
  description = "Whether to auto-stop the Vault VM nightly at 2:00 AM."
  type        = bool
  default     = true
}

variable "nightly_shutdown_time_zone" {
  description = "IANA time zone used for the nightly VM shutdown schedule."
  type        = string
  default     = "America/Chicago"
}

variable "enable_cloudsql_integration" {
  description = "Whether to create a Cloud SQL Postgres instance for Vault database secrets testing."
  type        = bool
  default     = false
}

variable "cloudsql_instance_name" {
  description = "Cloud SQL instance name for Vault integration testing."
  type        = string
  default     = "vault-lab-pg"
}

variable "cloudsql_postgres_version" {
  description = "Cloud SQL Postgres engine version."
  type        = string
  default     = "POSTGRES_15"
}

variable "cloudsql_tier" {
  description = "Cloud SQL machine tier."
  type        = string
  default     = "db-custom-1-3840"
}

variable "cloudsql_database_name" {
  description = "Database name used for Vault dynamic credential grants."
  type        = string
  default     = "app"
}

variable "cloudsql_admin_username" {
  description = "Cloud SQL admin username used by Vault database plugin."
  type        = string
  default     = "vaultadmin"
}
