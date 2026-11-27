# T-Pot Honeypot on EC2

A CloudFormation (JSON) template that deploys [T-Pot](https://github.com/telekom-security/tpotce), Deutsche Telekom Security's multi-honeypot platform, on a single EC2 instance. It runs the **Standard / HIVE** edition: around 20 honeypots (Cowrie, Dionaea, Conpot, Honeytrap...), plus Elastic Stack dashboards, an attack map and Suricata, all in Docker.

## Architecture

- **Dedicated VPC** (`10.70.0.0/16`) with one public subnet and an internet gateway. The honeypot is isolated from your other workloads on purpose: it is *meant* to be attacked.
- **EC2 instance** (Debian 13, `t3.xlarge`, 128 GiB encrypted gp3) installs T-Pot unattended on first boot, then reboots.
- **Security group**:
  - TCP and UDP `1-64000` open to `0.0.0.0/0`. These are the honeypot ports.
  - TCP `64295` (admin SSH) and `64297` (web UI) are open **only** to `AdminCidr`.
  - `64001-65535` is closed to everyone else, which keeps T-Pot's management ports private.
- **Secrets Manager** generates the web UI password. The instance role can only read that one secret, so the password is never in the template, the parameters or the user data.
- **IMDSv2 only, hop limit 1**, so the honeypot containers can't reach the instance metadata or the role credentials.

## Considerations

- **Cost.** In `us-east-1`, `t3.xlarge` is about $0.17/hour (~$4/day, ~$120/month), plus ~$10/month for 128 GiB of gp3 and the outbound data transfer. Delete the stack when you're done.
- **It's a honeypot.** It will be scanned and attacked within minutes. Don't put anything else in its VPC, don't reuse its key pair, and check your organisation's policies (and the AWS [penetration testing policy](https://aws.amazon.com/security/penetration-testing/)) before running it in a work account.
- **Supported OS.** The T-Pot installer only runs on the *current* release of a distribution (Debian 13 today). The template reads the latest Debian 13 AMI from the public SSM parameter `/aws/service/debian/release/13/latest/amd64`. If T-Pot moves to a newer Debian, override `DebianAmiId` or pin `TPotBranch` to a release tag that still supports Debian 13.
- **Install window.** Until the first reboot (~15-30 minutes), the real `sshd` still listens on port 22, with key-only authentication. After the reboot, port 22 is the Cowrie honeypot and admin SSH is on `64295`.

## Prerequisites

1. AWS CLI with credentials.
2. An EC2 key pair in the region (`aws ec2 create-key-pair --key-name tpot --query KeyMaterial --output text > tpot.pem && chmod 400 tpot.pem`).
3. Your public IP: `curl -s https://checkip.amazonaws.com`.

## Launch using the CLI

Run from the `Tpot-HoneyPot` folder:

```bash
aws cloudformation create-stack \
  --region us-east-1 \
  --stack-name tpot-honeypot \
  --template-body file://tpot-honeypot-cfn.json \
  --parameters \
      ParameterKey=AdminCidr,ParameterValue=$(curl -s https://checkip.amazonaws.com)/32 \
      ParameterKey=KeyName,ParameterValue=tpot \
  --capabilities CAPABILITY_IAM

aws cloudformation wait stack-create-complete --region us-east-1 --stack-name tpot-honeypot

aws cloudformation describe-stacks --region us-east-1 --stack-name tpot-honeypot \
  --query "Stacks[0].Outputs" --output table
```

Optional parameters: `WebUsername` (default `tpotadmin`), `InstanceType`, `VolumeSize`, `TPotBranch` (pin a release tag for repeatable installs), `VpcCidr`/`SubnetCidr`, and the `Service`/`Environment`/`Owner`/`Project` tags.

## Connect

`CREATE_COMPLETE` only means the instance has started. T-Pot still needs **15-30 minutes** to install and reboot. You can follow it from the console (EC2 → instance → *Monitor and troubleshoot* → *Get system log*) or, before the reboot, over SSH on port 22: `tail -f /var/log/tpot-bootstrap.log`. The installer ends with `T-Pot installed, rebooting.`

1. Get the web password (the `WebPasswordCommand` output):

   ```bash
   aws secretsmanager get-secret-value --region us-east-1 \
     --secret-id <WebUserSecret ARN> --query SecretString --output text
   ```

2. Open `https://<PublicIp>:64297` (the `WebUiUrl` output), accept the self-signed certificate, and log in with `tpotadmin` and the password. From there you can open Kibana, the Attack Map, CyberChef, Elasticvue and Spiderfoot.
3. Admin shell: `ssh -i tpot.pem -p 64295 admin@<PublicIp>`.

If your IP changes, update the stack with a new `AdminCidr`. Only the security group is replaced.

## Clean up

```bash
aws cloudformation delete-stack --region us-east-1 --stack-name tpot-honeypot
```

The Secrets Manager secret is scheduled for deletion with the default 30-day recovery window.
