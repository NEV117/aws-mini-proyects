import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";
import * as apigateway from "@pulumi/aws-apigateway";

const config = new pulumi.Config();
const stageName = config.get("stageName") ?? "stage";

// Same tag set as the Terraform template, applied to every taggable resource.
const tags = {
    Service: config.get("service") ?? "sms-notification-service",
    Environment: config.get("environment") ?? "dev",
    Owner: config.get("owner") ?? "cloud-platform-team",
    Project: config.get("project") ?? "aws-mini-projects",
};

const provider = new aws.Provider("provider", {
    region: aws.config.requireRegion(),
    defaultTags: { tags },
});
const opts = { provider };

// IAM role the Lambda runs as: CloudWatch logs + SNS publish (SMS to a phone
// number has no topic ARN, so sns:Publish must be on "*").
const role = new aws.iam.Role("lambda-execution-role", {
    assumeRolePolicy: aws.iam.assumeRolePolicyForPrincipal({ Service: "lambda.amazonaws.com" }),
}, opts);

new aws.iam.RolePolicyAttachment("lambda-basic-execution", {
    role: role.name,
    policyArn: aws.iam.ManagedPolicy.AWSLambdaBasicExecutionRole,
}, opts);

new aws.iam.RolePolicy("lambda-sns-publish", {
    role: role.id,
    policy: JSON.stringify({
        Version: "2012-10-17",
        Statement: [{ Effect: "Allow", Action: "sns:Publish", Resource: "*" }],
    }),
}, opts);

// Lambda packaged straight from ../lambda_code: Pulumi zips and uploads it, so
// there is no function.zip or S3 bucket to manage.
const fn = new aws.lambda.Function("send-sms", {
    runtime: aws.lambda.Runtime.NodeJS22dX,
    handler: "index.handler",
    role: role.arn,
    timeout: 30,
    code: new pulumi.asset.FileArchive("../lambda_code"),
}, opts);

// REST API with POST /send-sms -> Lambda (proxy integration). The component
// creates the deployment, stage and the lambda:InvokeFunction permission.
const api = new apigateway.RestAPI("sms-lambda-api", {
    stageName,
    routes: [{ path: "/send-sms", method: "POST", eventHandler: fn }],
}, { providers: { aws: provider } });

export const functionName = fn.name;
export const url = api.url;
export const sendSmsUrl = pulumi.interpolate`${api.url}send-sms`;
