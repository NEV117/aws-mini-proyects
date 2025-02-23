# Highly available web app (employee directory)

The `Employee Directory Web Application` is designed to be a `highly available` and scalable system deployed on AWS using CloudFormation. This infrastructure ensures reliability and performance by leveraging multiple AWS services.

The application is hosted on Amazon `EC2 instances` within an `Auto Scaling Group (ASG)`. This setup dynamically adjusts the number of instances based on demand, ensuring that the application can handle varying levels of traffic efficiently. The instances are distributed across `multiple Availability Zones (AZs)`, which enhances fault tolerance. If one availability zone fails, the application remains operational through instances in other zones.

To efficiently manage incoming traffic, an `Application Load Balancer (ALB)` is used. The ALB distributes requests among the EC2 instances, improving performance and availability. Additionally, it performs health checks on instances and automatically reroutes traffic to healthy ones, ensuring a seamless user experience.

The application stores employee data in `DynamoDB`, a fully managed NoSQL database that scales automatically. This eliminates the need for manual database management and ensures high availability. Employee images are stored in Amazon `S3`, which offers durable and secure storage. The S3 bucket policy restricts access to authorized roles, ensuring data security.

Security is enforced through `IAM roles` and `security groups`. The EC2 instances are granted limited permissions using an IAM instance profile, which allows them to interact with S3 and DynamoDB without exposing credentials. Security groups control inbound and outbound traffic, restricting access to essential ports such as port 80 for HTTP and port 22 for SSH.

![architecture-diagram](img/architecture.png)

## Components Created

- S3 Bucket: Stores images with a bucket policy to control access.
- DynamoDB Table: Named "Employees" to store employee data.
- IAM Role: S3DynamoDBFullAccessRole with full access to S3 and DynamoDB.
- Launch Template: For EC2 instances with a user data script to set up the application.
- Application Load Balancer: Distributes incoming traffic across multiple targets.
- Auto Scaling Group: Manages the number of EC2 instances based on demand.

## Parameters

- VPCId: ID of the VPC where resources will be created.
- SubnetIds: List of Subnet IDs for the ALB and Auto Scaling Group.
- KeyName: Name of an existing KeyPair for SSH access to EC2 instances.
- InstanceType: EC2 instance type (default: t2.micro).
- DesiredCapacity: Desired number of instances in the Auto Scaling Group (default: 1).
- MinSize: Minimum number of instances in the Auto Scaling Group (default: 1).
- MaxSize: Maximum number of instances in the Auto Scaling Group (default: 3).
- AccountNumber: AWS account number for the S3 bucket policy.
- ImagesBucketName: Name of the S3 bucket to store images (default: employee-directory-web-app).

## How to Execute

Ensure you have the AWS CLI installed and configured with the necessary permissions.

To deploy this stack using `terraform` go to the [terraform-folder](./terraform) and follow the instructions

- Deploy the Stack:
- Save the template to a file, e.g., employee-directory-template.yaml.
- Run the following command to create the stack:

```bash
aws cloudformation create-stack --stack-name EmployeeDirectoryStack \
  --template-body file://employee-directory.yml \
  --parameters ParameterKey=VPCId,ParameterValue=<VPC-ID> \
               ParameterKey=SubnetIds,ParameterValue=<Subnet-1,Subnet-2> \
               ParameterKey=KeyName,ParameterValue=<Key-Pair> \
  --capabilities CAPABILITY_NAMED_IAM

```

Replace placeholders (e.g., <your-vpc-id>) with actual values.

## Monitor the Stack

Use the AWS Management Console or CLI to monitor the stack creation process.

Access the Application: Once the stack is created, access the application using the DNS name of the Application Load Balancer, which is output as LoadBalancerDNSName.

## Acknowledgments

The code used in this repo comes from aws skill builder [AWS Technical Essentials](https://aws.amazon.com/training/classroom/aws-technical-essentials/) course

This implementation doesn't aim to claim credit for this code or course. It intends to expand on it by showing how infrastructure as code could be implemented.
