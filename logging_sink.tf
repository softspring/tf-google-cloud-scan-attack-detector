resource "google_logging_project_sink" "notfound_sink" {
  project     = var.project
  name        = "${var.resource_prefix}-notfound-requests"
  destination = "pubsub.googleapis.com/projects/${var.project}/topics/${google_pubsub_topic.income_notfound_request.name}"
  filter      = var.sink_filter
}

resource "google_pubsub_topic" "income_notfound_request" {
  project = var.project
  name    = "${var.resource_prefix}-income-notfound-request"
}
