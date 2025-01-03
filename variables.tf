variable "project" {
  type        = string
  description = "The GCP project to deploy to"
}

variable "region" {
  type        = string
  description = "The GCP region to deploy to"
  default     = "europe-west1"
}

variable "resource_prefix" {
  type        = string
  description = "The prefix to use for all resources"
  default     = "scan-attack-detector"
}

variable "not_found_request_window" {
  type        = number
  description = "The time window to check for not found requests (finally, the TTL of the requests)"
  default     = 60
}

output "not_found_request_window" {
  value = var.not_found_request_window
}

variable "not_found_request_limit" {
  type        = number
  description = "The limit of not found requests in the time window to trigger an attack"
  default     = 10
}

output "not_found_request_limit" {
  value = var.not_found_request_limit
}

variable "sink_filter" {
  type        = string
  description = "The filter to use for the sink"
  default     = "protoPayload.status=404 OR httpRequest.status=404"
}

output "sink_filter" {
  value = var.sink_filter
}

variable "temporary_artifact_bucket_name" {
  type        = string
  description = "The name of the temporary artifact bucket"
}

variable "redis_host" {
  type        = string
  description = "The host of the Redis instance"
}

variable "redis_port" {
  type        = number
  description = "The port of the Redis instance"
  default     = 6379
}

variable "redis_database" {
  type        = number
  description = "The database of the Redis instance (0 to 15)"
  default     = 0
}

variable "redis_vpc_connector_id" {
  type        = string
  description = "The ID of the VPC connector to use for the Redis instance"
  default     = null
}

variable "redis_vpc_connector_egress_settings" {
  type        = string
  description = "The egress settings to use for the VPC connector"
  default     = null
}

variable "function_available_memory" {
  type        = string
  description = "The available memory for the function"
  default     = "256M"
}

variable "function_max_instance_count" {
  type        = number
  description = "The maximum number of instances for the function"
  default     = 1
}