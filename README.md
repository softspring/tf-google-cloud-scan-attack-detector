# Scanning Attack Detector Terraform Module

This Terraform module creates a Scanning Attack detector on Google Cloud Platform (GCP). It sets up logging sinks 
and Pub/Sub topics to monitor and detect scanning attacks based on the 404 response code (Not Found).

## Usage

```hcl
module "scanning_attack_detector" {
  source                   = "github.com/softspring/tf-google-cloud-scan-attack-detector"

  project                 = "your-gcp-project-id"
  region                  = "europe-west1"
  resource_prefix         = "scan-attack-detector"
  not_found_request_window = 60
  not_found_request_limit  = 10
  sink_filter             = "protoPayload.status=404 OR httpRequest.status=404"
}
```

## Variables

- `project`: (Required) The GCP project to deploy to.
- `region`: (Optional) The GCP region to deploy to. Default is `europe-west1`.
- `resource_prefix`: (Optional) The prefix to use for all resources. Default is `scan-attack-detector`.
- `not_found_request_window`: (Optional) The time window to check for not found requests. Default is `60`.
- `not_found_request_limit`: (Optional) The limit of not found requests in the time window to trigger an attack. Default is `10`.
- `sink_filter`: (Optional) The filter to use for the sink. Default is `protoPayload.status=404 OR httpRequest.status=404`.

## Outputs

- `not_found_request_window`: The time window to check for not found requests.
- `not_found_request_limit`: The limit of not found requests in the time window to trigger an attack.
- `sink_filter`: The filter to use for the sink.

## Resources Created

- `google_logging_project_sink.notfound_sink`: A logging sink to capture 404 requests.
- `google_pubsub_topic.income_notfound_request`: A Pub/Sub topic to handle incoming 404 requests.

## Requirements

- Your GCP project must have the `Logging Admin` role on the service account.

## License

This project is licensed under the MIT License.