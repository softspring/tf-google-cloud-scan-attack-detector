resource "google_pubsub_subscription" "notfound_request_to_function" {
  project = var.project
  name    = "${var.resource_prefix}-income-notfound-request-to-function"
  topic   = google_pubsub_topic.income_notfound_request.name
}

data "google_storage_bucket" "source" {
  name = var.temporary_artifact_bucket_name
}

data "archive_file" "default" {
  type        = "zip"
  output_path = "/tmp/scan-attack-detector-function.zip"
  source_dir  = "${path.module}/detector-function/"
}

resource "google_storage_bucket_object" "object" {
  name   = "scan-attack-detector-function.zip"
  bucket = data.google_storage_bucket.source.name
  source = data.archive_file.default.output_path # Add path to the zipped function source code
}

resource "google_cloudfunctions2_function" "attack_detector" {
  project     = var.project
  name        = var.resource_prefix
  location    = var.region
  description = "Function to detect not found requests"

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
    max_instance_count = 1
    available_memory   = "256M"
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

