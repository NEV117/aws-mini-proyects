# Organization and Architecture: AWS Mini Projects

> **Test data.** The organization, people, and team names in this file are fictional and were created for testing. The systems and components match the infrastructure code in this repository.

## Organization

| Level | Name | Description |
|---|---|---|
| Business unit | Cloud Solutions | Builds and promotes reusable AWS infrastructure templates |
| Department | Engineering | Designs, builds, and operates the infrastructure |
| Department | Marketing | Writes the documentation and promotes the projects |
| Team | Cloud Platform Team | Part of the Engineering department |
| Team | Growth Team | Part of the Marketing department |

## Team members

The team has 3 people.

| Name | Role | Team | Department | Email | Responsibilities |
|---|---|---|---|---|---|
| Ana Torres | Senior Cloud Engineer (team lead) | Cloud Platform Team | Engineering | ana.torres@example.com | Architecture, CloudFormation and Terraform templates, security reviews |
| Ben Okafor | Software Engineer | Cloud Platform Team | Engineering | ben.okafor@example.com | Lambda code, web application, deployments |
| Carla Mendez | Marketing Manager | Growth Team | Marketing | carla.mendez@example.com | Project documentation, announcements, SMS campaigns |

## Systems

Each system has exactly one owning team.

| System | Owning team | Technical contact | Status | Description |
|---|---|---|---|---|
| SMS Notification Service | Cloud Platform Team | Ben Okafor | Active | REST API that sends SMS messages |
| Employee Directory Web App | Cloud Platform Team | Ana Torres | Active | Highly available web application for employee records and photos |
| macOS Remote Desktop | Cloud Platform Team | Ana Torres | Untested | macOS EC2 instance on a dedicated host |
| Project Documentation | Growth Team | Carla Mendez | Active | READMEs that explain and promote each project |

## Components

### SMS Notification Service

Source: `SMS-Lambda/`

| Component | Type | Purpose |
|---|---|---|
| SMS REST API | Amazon API Gateway | Receives HTTP POST requests |
| SMS Sender Function | AWS Lambda (Node.js) | Validates the request and publishes the message |
| SMS Execution Role | AWS IAM role | Grants the function its permissions |

### Employee Directory Web App

Source: `highly-available-web-app/`

| Component | Type | Purpose |
|---|---|---|
| Application Load Balancer | Elastic Load Balancing | Distributes traffic to the application instances |
| Application Target Group | Elastic Load Balancing | Tracks the instances that receive traffic |
| Application Auto Scaling Group | Amazon EC2 Auto Scaling | Scales the instances across Availability Zones |
| Application Launch Template | Amazon EC2 | Defines how instances are launched and bootstrapped |
| Flask Application | Python application on EC2 | Serves the employee directory |
| Employee Images Bucket | Amazon S3 | Stores employee photos |
| Employees Table | Amazon DynamoDB | Stores employee records |
| Application Instance Role | AWS IAM role | Grants the instances access to S3 and DynamoDB |

### macOS Remote Desktop

Source: `macOS-EC2/`

| Component | Type | Purpose |
|---|---|---|
| macOS Instance | Amazon EC2 | Runs the remote macOS desktop |
| macOS Dedicated Host | Amazon EC2 Dedicated Host | Provides the hardware the instance requires |
| macOS Security Group | Amazon EC2 security group | Controls network access to the instance |
| macOS Instance Role | AWS IAM role | Grants the instance its permissions |

### Project Documentation

Source: `README.md` and the `README.md` file in each project folder

| Component | Type | Purpose |
|---|---|---|
| Repository README | Markdown | Introduces the collection of projects |
| Project READMEs | Markdown | Explain how to deploy and use each project |

## Dependencies

### Within a system

| Component | Depends on | Reason |
|---|---|---|
| SMS REST API | SMS Sender Function | Forwards each POST request to the function |
| SMS Sender Function | SMS Execution Role | Uses the role's permissions |
| Application Load Balancer | Application Target Group | Forwards traffic to the group |
| Application Target Group | Application Auto Scaling Group | Receives its instances from the group |
| Application Auto Scaling Group | Application Launch Template | Launches instances from the template |
| Application Launch Template | Flask Application | Installs the application at startup |
| Application Launch Template | Application Instance Role | Attaches the role to each instance |
| Flask Application | Employee Images Bucket | Reads and writes photos |
| Flask Application | Employees Table | Reads and writes records |
| macOS Instance | macOS Dedicated Host | Runs on the host |
| macOS Instance | macOS Security Group | Uses the group's network rules |
| macOS Instance | macOS Instance Role | Uses the role's permissions |

### Between systems

| Component | System | Depends on | System | Reason |
|---|---|---|---|---|
| Project READMEs | Project Documentation | SMS REST API | SMS Notification Service | Documents how to call the API |
| Project READMEs | Project Documentation | Application Load Balancer | Employee Directory Web App | Documents how to reach the application |
| Project READMEs | Project Documentation | macOS Instance | macOS Remote Desktop | Documents how to launch the instance |

### External services

| Component | Depends on | Reason |
|---|---|---|
| SMS Sender Function | Amazon SNS | Delivers the SMS messages |
| Flask Application | AWS training S3 bucket | Provides `FlaskApp.zip` at startup |
