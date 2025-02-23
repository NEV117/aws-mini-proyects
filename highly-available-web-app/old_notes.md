# Notes



## Create s3 bucket to store the images

create s3 bucket:
-ACLS disabled
-bucket in same region

bucket policies:

```json
{
    "Version": "2012-10-17", 
    "Statement": [
        {
            "Sid": "AllowS3ReadAccess",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::<INSERT-ACCOUNT-NUMBER>: role/S3DynamoDBFullAccessRole"
            },
            "Action": "s3:*",
            "Resource":[
                "arn:aws:s3:::<INSERT-BUCKET-NAME>",
                "arn:aws:s3:::<INSERT-BUCKET-NAME>/*"
                ]
            }
        ]
    }
```

## Create dynamoDB table

table name = Employees

Partition key = string: id

## ROLE

S3DynamoDBFullAccessRole

Trustd entity type: AWS service
Common use cases: EC2

Permissions policies (AWS Managed Policies):

- AmazonS3FullAccess
- AmazonDynamoDBFullAccess

# Launching the load baalncer and the autoscaling group

## Launch app instance (EC2)

Attach role on ec2 instance

ec2 config:

- instance type: t2.micro
- os: amazon linux 2023
- key pair: your-key-pair
- security group: your-security-group (Inbound on 80, 22) (outbound 443)
- S3DynamoDBFullAccessRole
- Availability-zone on us-east-a or us-east-b

user-data:
```bash
#!/bin/bash -ex
wget https://aws-tc-largeobjects.s3-us-west-2.amazonaws.com/DEV-AWS-MO-GCNv2/FlaskApp.zip
unzip FlaskApp.zip
cd FlaskApp/
yum -y install python3-pip
pip install -r requirements.txt
yum -y install stress
export PHOTOS_BUCKET=employee-directory-web-app 
export AWS_DEFAULT_REGION=us-east-1
export DYNAMO_MODE=on
FLASK_APP=application.py /usr/local/bin/flask run --host=0.0.0.0 --port=80
```

## Create Application Load Balancer (ABL)

Apllication load balancer:

- internet-facing load balancer

- load balancer IP address type


Network:
- VPC: your-vpc
- 2 availability zones (us-east-1a) (us-east-1b)

Security Group
- HTTP (inbound)
- All access (outbound)


Target Group

- type: instance
- vpc and subnet must be the same as teh previuos configuration 

Healt checks:

- protocol: HTTP
- health cheack path: /
- port: Traffic port
- Healty threshould : 2
- Unhealthy threshould : 5
- Timeout: 30
- Interval: 40
- success code: 200

Check load balancer on  ABL dns name

## Launch template

- confugure the same as the ec2
- it is needed to configure the vpc but not the az's

## Auto scaling group

- set the previuos launch template
- set desire capacity
- set scaling limits (min - max)
- set network availablility zones

