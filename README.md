# Scanning Attack Detector Terraform Module

This Terraform module creates a Scanning Attack detector on Google Cloud Platform (GCP). It sets up logging sinks 
and Pub/Sub topics to monitor and detect scanning attacks based on the 404 response code (Not Found).

## Usage

```hcl
data "google_storage_bucket" "artifacts" {
  name = "your-gcp-bucket-name-for-artifacts"
}

data "google_redis_instance" "redis" {
  project = "your-gcp-project-id"
  name    = "your-redis-instance-name"
}

data "google_vpc_access_connector" "connector" {
  project = "your-gcp-project-id"
  name    = "your-vpc-access-connector-name"
}

module "scanning_attack_detector" {
  source  = "github.com/softspring/tf-google-cloud-scan-attack-detector"
  project = "your-gcp-project-id"
  region  = "europe-west1"

  temporary_artifact_bucket_name = data.google_storage_bucket.artifacts.name

  not_found_request_window = 60
  not_found_request_limit  = 10

  sink_filter = "protoPayload.status=404 OR httpRequest.status=404"

  redis_host     = data.google_redis_instance.redis.host
  redis_port     = data.google_redis_instance.redis.port
  redis_database = 15

  redis_vpc_connector_id              = data.google_vpc_access_connector.connector.id
  redis_vpc_connector_egress_settings = "PRIVATE_RANGES_ONLY"
}
```

## Variables

- `project`: (Required) The GCP project to deploy to.
- `region`: (Optional) The GCP region to deploy to. Default is `europe-west1`.
- `resource_prefix`: (Optional) The prefix to use for all resources. Default is `scan-attack-detector`.
- `not_found_request_window`: (Optional) The time window to check for not found requests. Default is `60`.
- `not_found_request_limit`: (Optional) The limit of not found requests in the time window to trigger an attack. Default is `10`.
- `sink_filter`: (Optional) The filter to use for the sink. Default is `protoPayload.status=404 OR httpRequest.status=404`.
- `temporary_artifact_bucket_name`: (Required) The name of the bucket to use for temporary artifacts.
- `redis_host`: (Required) The host of the Redis instance.
- `redis_port`: (Required) The port of the Redis instance. Default is `6379`.
- `redis_database`: (Required) The database to use in the Redis instance. Default is `0`.
- `redis_vpc_connector_id`: (Optional) The ID of the VPC Access Connector to use for the Redis instance. Default is `null`.
- `redis_vpc_connector_egress_settings`: (Optional) The egress settings to use for the VPC Access Connector. Default is `null`.

## Outputs

- `not_found_request_window`: The time window to check for not found requests.
- `not_found_request_limit`: The limit of not found requests in the time window to trigger an attack.
- `sink_filter`: The filter to use for the sink.
- `attack_detector_function`: The name of the Cloud Function created to detect attacks.
- `attack_detected_topic`: The name of the Pub/Sub topic to publish detected attacks.

## Resources Created

- `google_logging_project_sink.notfound_sink`: A logging sink to capture 404 requests.
- `google_pubsub_topic.income_notfound_request`: A Pub/Sub topic to handle incoming 404 requests.

## Requirements

- Your GCP project must have the `Logging Admin` role on the service account (in other case, you will see "logging.sinks.create" permission error).

## License

This project is licensed under the MIT License.