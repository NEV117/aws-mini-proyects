# Deploy with Pulumi

Pulumi (TypeScript) version of the SMS Lambda infrastructure, modeled on Pulumi's
[AWS Serverless Application template](https://www.pulumi.com/dev/templates/serverless-application/aws/).
It creates the same stack as the Terraform template:

- **IAM role** for the Lambda: CloudWatch Logs (`AWSLambdaBasicExecutionRole`) plus `sns:Publish`.
- **Lambda function** (Node.js 22, `index.handler`, 30 s timeout) built from `../lambda_code`.
- **API Gateway REST API** with `POST /send-sms` (Lambda proxy integration), deployed to the `stage` stage.

Differences from Terraform: Pulumi zips and uploads `../lambda_code` itself, so there is no
`function.zip` to build and no S3 code bucket. Tags are applied to every resource through the
provider's `defaultTags`.

## Prerequisites

1. Read the README in the parent folder, including the **Amazon SNS SMS setup** (spend limit, sandbox phone numbers).
2. [Pulumi CLI](https://www.pulumi.com/docs/install/) and Node.js 22+.
3. AWS credentials (`aws configure` or `aws login`).

## How to Use

```bash
cd SMS-Lambda/pulumi
npm install
pulumi login                       # Pulumi Cloud, or `pulumi login --local` for a local state file
pulumi stack init dev              # uses Pulumi.dev.yaml (aws:region = us-east-1)
pulumi up
```

Optional config (defaults in `Pulumi.yaml`):

```bash
pulumi config set aws:region us-west-2
pulumi config set environment prod      # also: service, owner, project (tags), stageName
```

## Test the API

```bash
curl -X POST "$(pulumi stack output sendSmsUrl)" \
  -H "Content-Type: application/json" \
  -d '{"countryCode": "1", "phoneNumber": "234567890", "message": "Hello from AWS"}'
```

After editing `../lambda_code/index.mjs`, run `pulumi up` again to redeploy.

## Clean up

```bash
pulumi destroy
pulumi stack rm dev
```
