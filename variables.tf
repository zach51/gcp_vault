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
  description = "GCP zone used by the Google provider (required by some gcloud commands)."
  type        = string
  default     = "us-central1-a"
}

variable "name_prefix" {
  description = "Name prefix applied to all lab resources."
  type        = string
  default     = "vault-lab"
}

variable "admin_cidrs" {
  description = "CIDR ranges allowed to reach the Vault LoadBalancer service (port 8200)."
  type        = list(string)
}

variable "network_cidr" {
  description = "Primary CIDR block for the GKE subnet."
  type        = string
  default     = "10.70.0.0/20"
}

variable "pods_secondary_cidr" {
  description = "Secondary CIDR block for GKE pods."
  type        = string
  default     = "10.71.0.0/16"
}

variable "services_secondary_cidr" {
  description = "Secondary CIDR block for GKE services."
  type        = string
  default     = "10.72.0.0/20"
}

variable "gke_release_channel" {
  description = "GKE release channel."
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE", "UNSPECIFIED"], var.gke_release_channel)
    error_message = "gke_release_channel must be RAPID, REGULAR, STABLE, or UNSPECIFIED."
  }
}

variable "gke_node_machine_type" {
  description = "Machine type for GKE nodes."
  type        = string
  default     = "e2-medium"
}

variable "gke_node_count" {
  description = "Initial node count for the Vault node pool."
  type        = number
  default     = 1
}

variable "gke_enable_autoscaling" {
  description = "Enable GKE node pool autoscaling. Keep false when using scheduled scale down."
  type        = bool
  default     = false
}

variable "gke_min_node_count" {
  description = "Autoscaler minimum node count."
  type        = number
  default     = 1
}

variable "gke_max_node_count" {
  description = "Autoscaler maximum node count."
  type        = number
  default     = 1
}

variable "gke_node_disk_size_gb" {
  description = "Boot disk size in GB for GKE nodes."
  type        = number
  default     = 30
}

variable "gke_node_disk_type" {
  description = "Boot disk type for GKE nodes."
  type        = string
  default     = "pd-standard"
}

variable "gke_preemptible_nodes" {
  description = "Whether GKE nodes should be preemptible (cheaper, can be reclaimed by GCP)."
  type        = bool
  default     = true
}

variable "enable_scheduled_scale_down" {
  description = "Whether to automatically scale the Vault node pool to 0 during off-hours and restore it daily."
  type        = bool
  default     = true
}

variable "scheduled_scale_down_cron" {
  description = "Cron schedule for scaling node pool down to 0."
  type        = string
  default     = "0 2 * * *"
}

variable "scheduled_scale_up_cron" {
  description = "Cron schedule for restoring node pool size."
  type        = string
  default     = "0 7 * * *"
}

variable "scheduled_scale_timezone" {
  description = "IANA timezone for scheduled node pool scale jobs."
  type        = string
  default     = "America/Chicago"
}

variable "scheduled_daytime_node_count" {
  description = "Node count to restore during scheduled scale-up."
  type        = number
  default     = 1
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace where Vault will be deployed."
  type        = string
  default     = "vault"
}

variable "vault_release_name" {
  description = "Helm release name for Vault."
  type        = string
  default     = "vault"
}

variable "vault_version" {
  description = "Vault image tag used by the Helm chart."
  type        = string
  default     = "1.17.5"
}

variable "vault_helm_chart_version" {
  description = "Optional HashiCorp Vault Helm chart version (null uses latest available)."
  type        = string
  default     = null
  nullable    = true
}

variable "vault_storage_size" {
  description = "Persistent volume size for Vault data."
  type        = string
  default     = "10Gi"
}

variable "vault_storage_class" {
  description = "Optional Kubernetes storage class for Vault PVC (empty uses cluster default)."
  type        = string
  default     = ""
}

variable "vault_log_level" {
  description = "Vault server log level."
  type        = string
  default     = "info"
}

variable "vault_service_annotations" {
  description = "Annotations to apply to the Vault service."
  type        = map(string)
  default     = {}
}
