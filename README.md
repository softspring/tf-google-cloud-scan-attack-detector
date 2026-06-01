# Google Cloud Scan Attack Detector Terraform Module

[![Terraform](https://img.shields.io/badge/Terraform-module-623CE4?style=flat-square&logo=terraform)](https://www.terraform.io/)
[![Google Cloud](https://img.shields.io/badge/Google%20Cloud-Functions%20%2B%20Pub%2FSub-4285F4?style=flat-square&logo=googlecloud)](https://cloud.google.com/functions)
[![Node.js](https://img.shields.io/badge/Node.js-runtime-5FA04E?style=flat-square&logo=nodedotjs)](https://nodejs.org/)
[![CI](https://img.shields.io/github/actions/workflow/status/softspring/tf-google-cloud-scan-attack-detector/ci.yml?branch=main&style=flat-square&label=CI)](https://github.com/softspring/tf-google-cloud-scan-attack-detector/actions/workflows/ci.yml)

Terraform module that detects possible HTTP scanning attacks in Google Cloud from repeated `404 Not Found` log entries.

The module wires Cloud Logging, Pub/Sub, a Cloud Functions v2 function, and Redis. It collects matching log entries, counts recent not-found requests by source IP in Redis, and publishes an attack event when an IP reaches the configured threshold inside the configured time window.

## What It Creates

By default, the module creates:

- one Cloud Logging project sink for not-found requests;
- one Pub/Sub topic that receives matching log entries;
- one Pub/Sub IAM binding that lets the logging sink publish to that topic;
- one Cloud Functions v2 function triggered by the incoming Pub/Sub topic;
- one Pub/Sub topic where detected attack events are published;
- one zip artifact with the detector function source uploaded to the provided artifact bucket.

Redis is not created by this module. The caller must provide an existing Redis host and, when needed, a Serverless VPC Access connector that lets the function reach Redis.

## Example

```hcl
data "google_storage_bucket" "artifacts" {
  name = "my-project-terraform-artifacts"
}

data "google_redis_instance" "redis" {
  project = var.project_id
  region  = "europe-west1"
  name    = "app-cache"
}

data "google_vpc_access_connector" "serverless" {
  project = var.project_id
  region  = "europe-west1"
  name    = "serverless-connector"
}

module "scan_attack_detector" {
  source = "github.com/softspring/tf-google-cloud-scan-attack-detector"

  project = var.project_id
  region  = "europe-west1"

  resource_prefix                = "scan-attack-detector"
  temporary_artifact_bucket_name = data.google_storage_bucket.artifacts.name

  sink_filter = "protoPayload.status=404 OR httpRequest.status=404"

  not_found_request_window = 60
  not_found_request_limit  = 10

  redis_host     = data.google_redis_instance.redis.host
  redis_port     = data.google_redis_instance.redis.port
  redis_database = 15

  redis_vpc_connector_id              = data.google_vpc_access_connector.serverless.id
  redis_vpc_connector_egress_settings = "PRIVATE_RANGES_ONLY"

  function_runtime            = "nodejs22"
  function_available_memory   = "256M"
  function_max_instance_count = 1
}
```

Consumers can subscribe to `module.scan_attack_detector.attack_detected_topic` to react to detected scans, for example by creating alerts, feeding an incident pipeline, or updating a blocking policy in another system.

## Detection Flow

1. Cloud Logging exports log entries matching `sink_filter` to the incoming Pub/Sub topic.
2. The detector function receives each Pub/Sub message.
3. The function extracts the source IP from `protoPayload.ip` or `httpRequest.remoteIp`.
4. The function extracts the requested resource from `protoPayload.resource` or `httpRequest.requestUrl`.
5. The function stores one Redis key per not-found request using a TTL of `not_found_request_window` seconds.
6. When the number of recent keys for the same IP reaches `not_found_request_limit`, the function publishes an attack event.

The published attack event has this JSON shape:

```json
{
  "ip": "203.0.113.10",
  "count": 10
}
```

## Requirements

- Terraform 1.x.
- Google provider version compatible with Cloud Functions v2, Pub/Sub, Cloud Logging sinks, and Cloud Storage objects.
- Archive provider for packaging the detector function source.
- Random provider for generating the source artifact suffix.
- A Google Cloud project with billing enabled.
- An existing Cloud Storage bucket for temporary function source artifacts.
- An existing Redis instance reachable by the function.
- A Serverless VPC Access connector when Redis is only reachable through private networking.

Required Google Cloud APIs depend on the caller project, but typically include:

- Cloud Functions API.
- Cloud Build API.
- Cloud Run API.
- Eventarc API.
- Pub/Sub API.
- Cloud Logging API.
- Cloud Storage API.
- Serverless VPC Access API when `redis_vpc_connector_id` is used.

The identity applying Terraform needs permission to create logging sinks, Pub/Sub topics and IAM bindings, Cloud Functions v2 functions, Cloud Storage objects, and the related Eventarc trigger resources. In particular, missing `logging.sinks.create` usually means the Terraform identity lacks a role such as `roles/logging.admin`.

## Variables

| Name | Required | Default | Description |
| --- | --- | --- | --- |
| `project` | yes | | Google Cloud project id. |
| `temporary_artifact_bucket_name` | yes | | Existing Cloud Storage bucket used to upload the detector function source zip. |
| `redis_host` | yes | | Redis host used by the detector function. |
| `region` | no | `europe-west1` | Google Cloud region for the function and trigger. |
| `resource_prefix` | no | `scan-attack-detector` | Prefix used for created resource names. |
| `not_found_request_window` | no | `60` | Time window, in seconds, used as the Redis TTL for not-found request counters. |
| `not_found_request_limit` | no | `10` | Number of not-found requests from the same IP that triggers an attack event. |
| `sink_filter` | no | `protoPayload.status=404 OR httpRequest.status=404` | Cloud Logging sink filter used to select incoming log entries. |
| `redis_port` | no | `6379` | Redis port. |
| `redis_database` | no | `0` | Redis database number. |
| `redis_vpc_connector_id` | no | `null` | Serverless VPC Access connector id used by the detector function. |
| `redis_vpc_connector_egress_settings` | no | `null` | VPC connector egress setting, for example `PRIVATE_RANGES_ONLY`. |
| `function_runtime` | no | `nodejs22` | Cloud Functions v2 Node.js runtime id. |
| `function_available_memory` | no | `256M` | Memory available to the detector function. |
| `function_max_instance_count` | no | `1` | Maximum number of detector function instances. |

## Outputs

- `not_found_request_window`: configured detection window.
- `not_found_request_limit`: configured request threshold.
- `sink_filter`: configured Cloud Logging sink filter.
- `attack_detector_function`: full `google_cloudfunctions2_function` resource object for the detector.
- `attack_detected_topic`: full `google_pubsub_topic` resource object for detected attack events.

## Resource Names

With the default `resource_prefix = "scan-attack-detector"`, the module creates:

- Cloud Function: `scan-attack-detector`
- Logging sink: `scan-attack-detector-notfound-requests`
- Incoming Pub/Sub topic: `scan-attack-detector-income-notfound-request`
- Attack event Pub/Sub topic: `scan-attack-detector-attack`

## Operational Notes

- The detector function expects log entries to include either `protoPayload.ip` or `httpRequest.remoteIp`.
- The detector function expects the requested resource in either `protoPayload.resource` or `httpRequest.requestUrl`.
- Every matching log entry creates a Redis key with the prefix `sad:<ip>:` and a TTL equal to `not_found_request_window`.
- The function uses Redis `KEYS` to count recent entries for an IP. Keep the Redis database dedicated or low-volume enough for this access pattern.
- `function_max_instance_count` defaults to `1` to keep Redis counting behavior simple and limit downstream event fan-out.
- The function source zip is generated in the module directory during Terraform operations and uploaded to the configured artifact bucket.

## Security

Keep Redis private when possible and connect through Serverless VPC Access. The detector publishes attack events but does not block traffic by itself; any blocking or alerting action should be implemented by consumers of the attack event topic.

Review the `sink_filter` carefully before production use. Broad filters can forward high log volume into Pub/Sub and increase function invocations.

## License

This project is licensed under the MIT License.
