# Deploy with Terraform

If you prefer to use terraform for IaC here is a template you can modify, just make sure to set your bucket `name` and `key` in `main.tf`

## Prerequisites

Before starting, Make sure to read the readme in the parent folder and to have the following installed:

1. **Terraform**: Terraform: Download it from [Terraform Downloads](https://www.terraform.io/downloads) and install it according to your operating system.
2. **AWS CLI**: Download it from [AWS CLI](https://aws.amazon.com/cli/) and install it.
3. **AWS Credetials**: CConfigure your credentials by running:
   ```bash
   aws configure
    ```
4. **Lambda function code**: The Lambda function code must be packaged in a `.zip` file (e.g., `function.zip`) and uploaded to an S3 bucket.
5. **Configure Amazon SNS for SMS**:
   - **Enable SMS in SNS**:
     1. Go to the Amazon SNS console.
     2. In the sidebar, select **Text messaging (SMS)**.
     3. Click **Preferences** and adjust the following settings:
        - **Account spend limit**: Set a monthly spend limit (e.g., $1 USD for testing).
        - **Default message type**: Choose **Promotional** or **Transactional** depending on your use case. For testing, use **Transactional**.
   - **Validate phone numbers**:
     If your account is in sandbox mode, you must register phone numbers before sending SMS:
     1. Go to **Text messaging (SMS) > Phone numbers**.
     2. Register the phone number and verify the received message.

`main.tf`: Main Terraform configuration file.

## How to Use

### 1. **Upload your Lambda code to S3**

Before deploying the template, you must have your Lambda function code in a `.zip` file uploaded to an S3 bucket. You can do this via the S3 console or the AWS CLI.

(the funtion code is in /SMS-Lambda/lambda_code/index.mjs)

```bash
aws s3 cp function.zip s3://your-s3-bucket/
```

### 2. **Initialize Terraform**
Run the following command to initialize Terraform and download the required plugins:
```bash
terraform init
```
### 3. **Review the Execution Plan**
Before applying changes, review the execution plan:
```bash
terraform plan
```
This command shows the resources that will be created.

### 4. **Apply the Changes**
To deploy the resources on AWS, run:
```bash
terraform apply
```
Confirm by typing yes when prompted.

### 5. **Verify the Resources**
Once the execution is complete, you can verify the created resources:
 - Lambda Function: Check it in the AWS Lambda console.
 - API Gateway: Check it in the API Gateway console.

 Once deployed, the API Gateway will be running, and you can access it at the following URL (replace `ApiId` and `Region`):

```bash
https://<ApiId>.execute-api.<Region>.amazonaws.com/stage/send-sms
```
