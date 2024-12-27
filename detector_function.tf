data "google_storage_bucket" "source" {
  name = var.temporary_artifact_bucket_name
}

resource "random_string" "suffix" {
  length = 4
  lower  = true
}

locals {
  zip_file_name = "scan-attack-detector-function-${random_string.suffix.result}.zip"
}

data "archive_file" "default" {
  type        = "zip"
  source_dir  = "${path.module}/detector-function/"
  output_path = "${path.module}/${local.zip_file_name}"
}

resource "google_storage_bucket_object" "object" {
  name   = local.zip_file_name
  bucket = data.google_storage_bucket.source.name
  source = data.archive_file.default.output_path # Add path to the zipped function source code
}

resource "google_cloudfunctions2_function" "attack_detector" {
  project     = var.project
  name        = var.resource_prefix
  location    = var.region
  description = "Function to detect not found requests"

  labels = {
    "component" = "scan-attack-detector"
  }

  build_config {
    runtime     = "nodejs20"
    entry_point = "detectScanAttack"
    source {
      storage_source {
        bucket = data.google_storage_bucket.source.name
        object = google_storage_bucket_object.object.name
      }
    }
  }

  service_config {
    max_instance_count = var.function_max_instance_count
    available_memory   = var.function_available_memory
    timeout_seconds    = 60

    environment_variables = {
      "REDIS_HOST"               = var.redis_host,
      "REDIS_PORT"               = var.redis_port,
      "REDIS_DATABASE"           = var.redis_database,
      "NOT_FOUND_REQUEST_WINDOW" = var.not_found_request_window,
      "NOT_FOUND_REQUEST_LIMIT"  = var.not_found_request_limit,
      "ATTACK_PUBSUB_PROJECT"    = google_pubsub_topic.attack_detected.project,
      "ATTACK_PUBSUB_TOPIC"      = google_pubsub_topic.attack_detected.name,
    }

    vpc_connector                 = var.redis_vpc_connector_id
    vpc_connector_egress_settings = var.redis_vpc_connector_egress_settings
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.income_notfound_request.id
    retry_policy   = "RETRY_POLICY_RETRY"
  }
}

resource "google_cloud_run_service_iam_member" "member" {
  location = google_cloudfunctions2_function.attack_detector.location
  service  = google_cloudfunctions2_function.attack_detector.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

output "attack_detector_function" {
  value = google_cloudfunctions2_function.attack_detector
}

resource "google_pubsub_topic" "attack_detected" {
  project = var.project
  name    = "${var.resource_prefix}-attack"
}

output "attack_detected_topic" {
  value = google_pubsub_topic.attack_detected
}

