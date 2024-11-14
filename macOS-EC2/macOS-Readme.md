# Ec2 macOS remote desktop
Here is a little tutorial aiming to record how to launch a mac-os ec2 instance on aws using a predefined aws template.

### Considerations:
- macOS ec2 instances need of a dedicated host wich means a 24 hour commiment, a single cost-effective instance is almost $1 usd/hour wich means roughly $24/day per macOS instance

 - This template is designed to work on the `us-west-1` region using the `deault vpc` and the `most recent AMI` available of `creation date of this repo`, you could/should change this values as needed.

## Launch Using de CLI
Execute the following on `macOS-EC2 folder`:

```bash
aws cloudformation create-stack \
  --stack-name macos-ec2-ssm-single-user \
  --template-body file://macos-ec2.yml \
  --parameters \
      ParameterKey=RemoteUsername,ParameterValue=miusuario \
      ParameterKey=RemoteUserPassword,ParameterValue=MiContraseñaSegura \
  --capabilities CAPABILITY_IAM
```