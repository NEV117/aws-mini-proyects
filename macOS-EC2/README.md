# EC2 macOS remote desktop

A short tutorial on launching a macOS EC2 instance with a CloudFormation template, managing it with Systems Manager (SSM), and opening a remote desktop over Screen Sharing (VNC).

## Considerations

- macOS instances run on a **dedicated host** with a **24-hour minimum allocation**. A `mac2.metal` host costs about $0.65/hour in `us-east-1`, so roughly **$15.6/day**, and you pay for at least 24 h even if you delete the stack sooner.
- The template defaults to `us-east-1` and the latest **macOS Sequoia (arm64)** AMI, read from the public SSM parameter `/aws/service/ec2-macos/sequoia/arm64_mac/latest/image_id`. To use another version, pass `MacAmiId` (for example `/aws/service/ec2-macos/tahoe/arm64_mac/latest/image_id`).
- By default **no inbound port is opened**. You reach the Mac's Screen Sharing through an SSM port-forwarding tunnel. You can optionally open port 5900 to one IP with `AllowedVncCidr`.
- The remote user's password is passed in the instance user data, so anyone with `ec2:DescribeInstanceAttribute` in the account can read it. Use a throwaway password and change it after the first login.

## Prerequisites

1. **AWS CLI** with credentials, and the **Session Manager plugin** for the CLI (needed for the tunnel).
2. **Dedicated host quota.** New accounts often have a quota of 0 for Mac hosts. In Service Quotas → Amazon EC2, check *Running Dedicated mac2 Hosts* and request at least 1 if needed.
3. **An AZ that offers `mac2.metal`:**

   ```bash
   aws ec2 describe-instance-type-offerings --region us-east-1 \
     --location-type availability-zone \
     --filters Name=instance-type,Values=mac2.metal \
     --query "InstanceTypeOfferings[].Location" --output text
   ```

4. **The default VPC and a subnet in that AZ** (replace `us-east-1b` with an AZ from step 3):

   ```bash
   aws ec2 describe-subnets --region us-east-1 \
     --filters Name=default-for-az,Values=true Name=availability-zone,Values=us-east-1b \
     --query "Subnets[0].[VpcId,SubnetId]" --output text
   ```

## Launch using the CLI

Run from the `macOS-EC2` folder, replacing the AZ, VPC and subnet with your values:

```bash
aws cloudformation create-stack \
  --region us-east-1 \
  --stack-name macos-ec2-ssm-single-user \
  --template-body file://macos-ec2.yml \
  --parameters \
      ParameterKey=AvailabilityZone,ParameterValue=us-east-1b \
      ParameterKey=VpcId,ParameterValue=vpc-xxxxxxxx \
      ParameterKey=SubnetId,ParameterValue=subnet-xxxxxxxx \
      ParameterKey=RemoteUsername,ParameterValue=myuser \
      ParameterKey=RemoteUserPassword,ParameterValue='MySecure#Pass2026' \
  --capabilities CAPABILITY_IAM

aws cloudformation wait stack-create-complete --region us-east-1 --stack-name macos-ec2-ssm-single-user
```

The password may only use letters, digits and `@#%^&*`. Accented letters such as `ñ` are rejected. Keep the single quotes around it so your shell doesn't interpret the symbols.

To open VNC to your own IP as well, add `ParameterKey=AllowedVncCidr,ParameterValue=<your-ip>/32`.

## Launch using Terraform

The `terraform/` folder builds the same stack. By default it uses the region's **second AZ** (`us-east-1b` in `us-east-1`) and that AZ's default subnet in the default VPC, so only a password is required. Set `availability_zone` to use another AZ that offers `mac2.metal` (step 3 above).

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # set remote_user_password
terraform init
terraform plan
terraform apply
```

**Using a host you allocated yourself.** Set `host_id = "h-..."` in `terraform.tfvars`. Terraform then places the instance on that host, uses the host's AZ, and never releases the host on `destroy`, so you can rebuild the instance without the 24-hour wait. You allocate and release the host yourself (EC2 → Dedicated Hosts, or `aws ec2 allocate-hosts --instance-type mac2.metal --availability-zone us-east-1b --quantity 1`). Allocating by hand counts against the same mac2 host quota.

`terraform output screen_sharing_tunnel_command` prints the tunnel command used in [Connect](#connect). To tear down, run `terraform destroy`. Like the CloudFormation stack, destroying the host fails until 24 hours after it was allocated, so run it again after that.

`terraform.tfvars` holds the password and is git-ignored. The password is also stored in the Terraform state file, so keep the state private.

## Connect

The first boot of a Mac instance is slow. Allow **15–20 minutes** after `CREATE_COMPLETE` before the instance shows up in SSM:

```bash
aws ssm describe-instance-information --region us-east-1 \
  --query "InstanceInformationList[].[InstanceId,PingStatus]" --output text
```

Then get the tunnel command from the stack outputs and run it:

```bash
aws cloudformation describe-stacks --region us-east-1 \
  --stack-name macos-ec2-ssm-single-user \
  --query "Stacks[0].Outputs[?OutputKey=='ScreenSharingTunnelCommand'].OutputValue" --output text
```

While the tunnel is running, open `vnc://localhost:5900`. On macOS, use Finder → Go → Connect to Server. On Linux or Windows, use a VNC client such as TigerVNC or RealVNC. Sign in with `RemoteUsername` and `RemoteUserPassword`.

Optional: install macOS updates from a shell (`aws ssm start-session --target <instance-id>`) with `sudo softwareupdate -i -a`. Updates can take a long time and may restart the Mac.

## Teardown

```bash
aws cloudformation delete-stack --region us-east-1 --stack-name macos-ec2-ssm-single-user
```

The instance terminates right away, but the dedicated host **cannot be released until 24 hours after it was allocated**. If you delete earlier, the stack ends in `DELETE_FAILED` on the host. Run `delete-stack` again after the 24 hours have passed. Also check that no host remains in EC2 → Dedicated Hosts, since you're billed for as long as it exists.
