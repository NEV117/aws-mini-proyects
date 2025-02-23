# Deploy with Terraform

If you prefer to use terraform for IaC here is a template you can modify

## Prerequisites

Before starting, Make sure to read the readme in the parent folder and to have the following installed:

1. **Terraform**: Terraform: Download it from [Terraform Downloads](https://www.terraform.io/downloads) and install it according to your operating system.
2. **AWS CLI**: Download it from [AWS CLI](https://aws.amazon.com/cli/) and install it.
3. **AWS Credetials**: Configure your credentials by running:

   ```bash
   aws configure
    ```

## How to Use

### 1. Set Up Terraform variables by creating `terraform.tfvars` (example)

```bash
# terraform.tfvars
vpc_id        = "vpc-id"
subnet_ids    = ["subnet-1", "subnet-2", "subnet-3"]
key_name      = "your-ssh-key"
account_number = "aws-account-number"
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

Go to the aws console and verify the services created, or just go to the app usgin the output of the terraform execution

```bash
http://apploadbalancer-912260561.us-east-1.elb.amazonaws.com/info
```
