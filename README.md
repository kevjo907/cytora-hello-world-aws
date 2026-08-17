# Hello World on AWS — API Gateway + Lambda

A minimal HTTP "hello world" service on AWS, defined entirely in Terraform, with
a GitHub Actions pipeline that tests, plans, deploys and smoke-tests it.

```
client ──HTTPS──▶ API Gateway (HTTP API, $default stage)
                        │  AWS_PROXY integration, payload format 2.0
                        ▼
                  Lambda (Python 3.12, arm64, 128 MB)
                        │
                        ▼
                  CloudWatch Logs (structured JSON) + X-Ray traces
```

```console
$ curl https://<api-id>.execute-api.eu-west-1.amazonaws.com/hello
{
  "message": "Hello, World!",
  "stage": "dev",
  "path": "/hello",
  "method": "GET",
  "timestamp": "2026-08-17T18:42:11.204817+00:00",
  "request_id": "8f3c1e0a-5b2d-4a91-9c77-1f6b2e4d8a03"
}
```

## Layout

```
├── src/hello/handler.py         Lambda handler (Python, stdlib only)
├── tests/test_handler.py        Unit tests — 11 cases, no AWS required
├── terraform/
│   ├── main.tf                  Root module: wires the two modules together
│   ├── variables.tf             Inputs, with validation
│   ├── outputs.tf               Endpoint URL, function name, log groups
│   ├── backend.tf               Partial S3 backend (local state by default)
│   ├── modules/lambda/          Function, execution role, log group
│   ├── modules/api_gateway/     HTTP API, integration, routes, stage
│   └── bootstrap/               One-time: state bucket + GitHub OIDC role
├── .github/workflows/ci.yml     Lint, test, validate, plan (on PR)
├── .github/workflows/cd.yml     Test, apply, smoke test (on main)
└── Makefile                     Shortcuts for everything below
```

## Quick start

Requires Terraform >= 1.10 and Python >= 3.12.

```bash
make install       # pytest + ruff
make test          # unit tests, no AWS credentials needed
make validate      # terraform fmt + validate, no AWS credentials needed
```

To deploy into your own account:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
make plan
make apply
make smoke         # curl the live /hello endpoint
make destroy       # tear it down
```

`make apply` prints the endpoint as a Terraform output. Nothing here leaves the
AWS free tier at low traffic.

## Design decisions

**HTTP API, not REST API.** API Gateway v2 HTTP APIs are roughly 70% cheaper per
million requests than v1 REST APIs, add less latency, and use the leaner 2.0
payload format. A REST API only earns its cost when you need usage plans,
request validation, or direct WAF association — none of which a hello world
needs.

**Python with zero dependencies.** The handler imports only the standard
library, so the deployment package is a few kilobytes. That means fast cold
starts, no third-party CVEs to track, and no build step — Terraform's
`archive_file` zips the source directly. The `archive_file` data source is also
the natural seam to swap in a real build if dependencies ever arrive.

**arm64 (Graviton2).** Around 20% cheaper than x86_64 for the same workload,
with equal or better performance on a pure-Python function.

**Log groups declared explicitly.** If you let Lambda create its own log group
on first invocation, it has no retention policy and keeps logs — and charges for
them — forever. Declaring the group in Terraform sets 14-day retention and lets
the execution role drop the `logs:CreateLogGroup` permission entirely.

**Hand-written IAM instead of `AWSLambdaBasicExecutionRole`.** That managed
policy grants `logs:*` across every log group in the account. The inline policy
here allows `CreateLogStream` and `PutLogEvents` on this function's log group and
nothing else.

**Throttling on the stage.** A public, unauthenticated endpoint with no ceiling
turns a traffic spike straight into a bill. The stage caps at 50 req/s steady,
100 burst; both are variables.

**Structured JSON logs.** Both the Lambda and the API Gateway access logs emit
JSON, so CloudWatch Logs Insights can query fields directly without regex
parsing.

**Two modules, not one.** `modules/lambda` and `modules/api_gateway` are
independently reusable and testable; the root module only wires them together.
For a service this small it is slightly more structure than strictly necessary,
but it is the shape that scales to the second and third function.

## CI/CD

Two workflows, both keyed on OIDC — there are **no long-lived AWS keys in GitHub
secrets**.

| | `ci.yml` | `cd.yml` |
|---|---|---|
| Trigger | pull request, push to `main` | push to `main` (code paths only) |
| Steps | ruff lint + format, pytest, `terraform fmt`/`validate`, `terraform plan` | pytest, `terraform apply`, live smoke test |
| Plan output | posted as a PR comment | — |
| Credentials | OIDC, read + plan | OIDC, via `production` environment |

The `app` and `terraform` jobs need no credentials at all (`terraform init
-backend=false`), so they run on forked PRs. The `plan` and `deploy` jobs are
guarded by `if: vars.AWS_ROLE_ARN != ''`, so the pipeline stays green in a repo
that has never been wired to an AWS account.

The deploy job does not trust `terraform apply` exiting 0 as proof of success —
it curls the real endpoint afterwards, retrying five times, and fails the run if
`/hello` never returns 200 with a JSON `message` field.

### Wiring it to an AWS account

```bash
cd terraform/bootstrap
terraform init
terraform apply \
  -var="state_bucket_name=<globally-unique-name>" \
  -var="github_repository=<owner>/<repo>"
```

That creates the versioned, encrypted S3 state bucket and a GitHub OIDC role
scoped to `refs/heads/main` and pull requests **of that repository only**. Then
copy the outputs into repository variables:

```bash
gh variable set AWS_ROLE_ARN    --body "<github_actions_role_arn output>"
gh variable set TF_STATE_BUCKET --body "<state_bucket output>"
gh variable set AWS_REGION      --body "eu-west-1"
```

State locking uses S3's native `use_lockfile` (Terraform 1.10+), so there is no
DynamoDB table to maintain.

## Testing

```console
$ make test
11 passed
```

The tests exercise the handler as a pure function — status code, JSON body
fields, ISO-8601 UTC timestamp, security headers, method echo across GET/POST/
HEAD, and graceful handling of malformed events (`{}`, `None`, missing
`requestContext`) and a missing context object. No AWS account, no mocking
library, no network.

## Known trade-offs

Things deliberately left out, and what production would add:

- **No custom domain or TLS certificate.** The generated
  `execute-api.amazonaws.com` URL is fine for a demo; production would add ACM
  and a Route 53 record.
- **No authentication.** The assessment asks for a public hello world. A real
  endpoint would use a JWT authoriser or IAM auth.
- **Deploy role is broader than ideal.** `lambda:*` and `apigateway:*` are
  scoped to `*` because much of the naming is AWS-generated. IAM actions *are*
  scoped to `${project_name}-*` roles, since that is where the real blast radius
  lives. Production would add a permissions boundary.
- **Single environment.** `environment` is a variable and state keys are
  per-stack, so dev/staging/prod is a matter of separate tfvars and state keys
  rather than new code — but only one is wired up here.
- **No alarms.** Production would add CloudWatch alarms on Lambda errors, p99
  duration, and API Gateway 5xx rates.
