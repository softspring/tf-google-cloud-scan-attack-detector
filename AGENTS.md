# AGENTS.md

Operational rules for developers and automated agents working in this repository.

## Repository Scope

- This repository provides a reusable Terraform module for detecting repeated Google Cloud `404 Not Found` requests.
- The module should stay generic and reusable across Softspring and Armonic projects.
- Keep project-specific alerting, blocking, dashboards, and incident workflows in application repositories.
- Redis, artifact buckets, networking, and downstream consumers are owned by callers unless the module explicitly creates them.

## Read First

Before making changes, read:

1. `README.md`
2. this `AGENTS.md`
3. the Terraform files directly related to the task
4. `detector-function/index.js` when changing detection behavior

## Documentation Policy

- Keep durable project knowledge in `README.md`.
- Use `AGENTS.md` for working rules, validation rules, and recurring operational decisions.
- Write project documentation in English, even when the conversation is in Spanish.
- Keep documentation clear, direct, and practical.
- Do not document behavior that the module does not implement yet.
- Every public input and output must be documented in `README.md`.
- Examples must use realistic placeholder values without embedding real project ids, domains, credentials, or secrets.

## Terraform Conventions

- Use standard Terraform formatting.
- Prefer explicit variable types and descriptions.
- Keep provider configuration outside this reusable module.
- Keep resource names derived from input variables so the module can be reused safely.
- Avoid broad IAM roles unless there is a documented reason.
- Expose outputs that are useful for composition, but do not expose secrets.
- Treat variable names, output names, defaults, resource names, and event payload shape as module contract.

## Google Cloud Notes

- Cloud Logging exports matching log entries to Pub/Sub through a project sink.
- The sink writer identity must have `roles/pubsub.publisher` on the incoming topic.
- Cloud Functions v2 creates supporting Cloud Run, Cloud Build, Artifact Registry, and Eventarc resources behind the scenes.
- The detector function needs network access to Redis. Use Serverless VPC Access when Redis is private.
- The detected attack topic is an integration point for downstream alerting, blocking, or incident handling.

## Detector Function Notes

- Keep the detector source in `detector-function/`.
- The exported function name is `detectScanAttack`; changing it requires updating Terraform `entry_point`.
- The function reads configuration from environment variables defined in `detector_function.tf`.
- Detection currently counts Redis keys prefixed with `sad:<ip>:` and expiring after `NOT_FOUND_REQUEST_WINDOW` seconds.
- Published attack events are deduplicated per IP with Redis keys prefixed with `sad:attack-published:<ip>` and expiring after `ATTACK_EVENT_COOLDOWN_SECONDS`.
- Review Redis access patterns before changing counting behavior. Avoid introducing unbounded memory growth.

## Validation

Before considering Terraform changes complete, run from the repository root:

```bash
terraform fmt -recursive
terraform validate
```

When changing the Node.js detector function, also run the relevant package checks from `detector-function/`. If no test script exists, at least run:

```bash
npm install
npm ls --depth=0
```

Do not commit:

- `.terraform/`
- `.terraform.lock.hcl` changes unless provider version locking is intentional
- `terraform.tfstate`
- `terraform.tfstate.backup`
- `*.tfvars` files containing real environment values
- generated credentials or service account keys
- generated detector function zip files

## Change Discipline

- Make small, reviewable changes.
- Do not modify unrelated work.
- Keep documentation and examples synchronized with implemented behavior.
- If a module contract changes, document the migration clearly in the same change.
- Review IAM, networking, sink filters, Redis access, and event payload compatibility before finishing a task.
