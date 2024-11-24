# AWS Mini Projects

Here is a collection of CloudFormation templates for various AWS projects, providing reusable infrastructure as code solutions.

some proyects offer a close up setup and analisis of usecases and results, some of them dont

im expecting to document the following projects

- [MacOS-EC2](./macOS-EC2) (UNTESTED)
- [highly-available-web-app](./highly-available-web-app/)
- Tpot-HoneyPot (EC2)
- Tree tier level web app (vm's and containers)
- AutoScaling Web App Architecture
- AWS Lambda Function with API Gateway
- AWS Lambda Function processing SQS orders
<!-- 
- [Tpot-HoneyPot](./Tpot-HoneyPot)
- [Tree tier level web app](./three-tier-web-app)
- [AutoScaling Web App Architecture](./AutoScaling-Web-App)
- [AWS Lambda Function with API Gateway](./Lambda-API-Gateway)
- [AWS Lambda Function processing SQS orders](./Lambda-SQS) -->

## Considerations

- Default region is `us-east-1`, ami's and other configurations are intended to work in this region only (if someone is reusing this change these type of parameters as needed)
- Focus on `Cloud Formation` and `AWS CLI`
- Most projects are intended to be cost-effective so im using minimal resouces on the solutions.
- The projects are intended to be scalable so they can be easily expanded or modified as needed.
- The projects are intended to be secure so they use best practices for security and compliance.
- No problem on using this as a personal, educational, or comercial purposes but consider that im not reponsable for overspending or misconfigurations.
- The Code on the applications may not be the best it is not my focus, im keeping it simple :P