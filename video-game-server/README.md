# Minecraft Server with Auto Scaling (Terraform)

New Minecraft video game server as an example. Configuration for mods is not covered here.

A basic Minecraft Java Edition server on AWS, deployed with Terraform. It scales horizontally: when the servers get busy, the Auto Scaling group adds more of them behind one Network Load Balancer.

## Architecture

```text
Players ──TCP 25565──▶ Network Load Balancer (sticky by source IP)
                              │
                 ┌────────────┴────────────┐
                 ▼                         ▼
        EC2 Minecraft server  ...  EC2 Minecraft server     ◀── Auto Scaling group (1 to 4)
        (AZ a, public subnet)      (AZ b, public subnet)          scales on players and CPU
                 │                         │
                 └──── PlayersOnline ──────┴──▶ CloudWatch custom metric
```

| Component | AWS service | Purpose |
|---|---|---|
| VPC, 2 public subnets, internet gateway | Amazon VPC | Network across 2 Availability Zones, no NAT gateway to keep cost down |
| Network Load Balancer | Elastic Load Balancing | One address for players; sends new connections to the servers |
| Target group | Elastic Load Balancing | TCP health checks on the game port; source IP stickiness |
| Launch template | Amazon EC2 | Amazon Linux 2023, encrypted gp3 volume, IMDSv2 required, bootstrap script |
| Auto Scaling group | Amazon EC2 Auto Scaling | Runs the servers and replaces unhealthy ones |
| Target tracking policies | Amazon EC2 Auto Scaling | Scale on players per server and on CPU |
| `MinecraftServer/PlayersOnline` metric | Amazon CloudWatch | Player count each server publishes every minute |
| Instance role | AWS IAM | Session Manager access, and permission to publish the metric and write the server logs |
| CloudWatch agent | Amazon CloudWatch | Ships the server logs from each instance |
| Log groups | Amazon CloudWatch Logs | Keep the server, bootstrap, player metric and VPC flow logs |
| Logs KMS key | AWS KMS | Encrypts all log groups; automatic key rotation |
| VPC Flow Logs | Amazon VPC | Records network traffic to and from the servers |

## How the scaling works

- Each server counts its established connections on port 25565 every minute and sends the number to CloudWatch as `PlayersOnline`.
- **Players policy:** keeps the average players per server near `target_players_per_server` (default 10).
- **CPU policy:** keeps the average CPU near `target_cpu_percent` (default 70%).
- The group adds a server when either policy is above its target. It removes one only when both are below.
- Limits: `min_servers` = 1, `max_servers` = 4.

> **Every server has its own world.** Minecraft cannot share one world between several running servers. Scaling adds new, separate worlds. The load balancer uses source IP stickiness so a returning player normally lands on the same server. If you need one shared world for everybody, use a single larger instance (set `min_servers = max_servers = 1`) or a proxy such as Velocity with lobby and game servers. Neither is part of this project.

## Logging

The CloudWatch agent on each server sends its logs to CloudWatch Logs. Each server writes to a log stream named after its instance ID, so its logs remain after the server is removed.

| Log group | Source | Contents |
|---|---|---|
| `/minecraft/<env>/server` | `/opt/minecraft/logs/latest.log` | Minecraft server log: startup, player joins and leaves, chat, errors |
| `/minecraft/<env>/bootstrap` | `/var/log/cloud-init-output.log` | Output of the startup script (Java and server install) |
| `/minecraft/<env>/player-metric` | `/var/log/player-metric.log` | Player count each minute and any errors publishing the metric |
| `/minecraft/<env>/vpc-flow` | VPC Flow Logs | Accepted and rejected network traffic in the VPC |

- **Retention:** `log_retention_days` (default 30 days; `0` keeps logs forever).
- **Encryption:** every log group uses a customer managed KMS key with automatic rotation.
- **Access:** the servers can only write to their own three log groups.
- **VPC Flow Logs:** enabled by default; turn them off with `enable_vpc_flow_logs = false`.
- **Load balancer:** the NLB has no access logs, because AWS only writes them for TLS listeners and this one is plain TCP. VPC Flow Logs cover its traffic.
- **CloudTrail:** this project doesn't create a trail. API activity is normally logged by an account-wide trail.

Follow the server log live:

```bash
aws logs tail /minecraft/dev/server --follow
```

## Compliance tags

Every resource gets these four tags:

| Tag | Variable | Default |
|---|---|---|
| `Service` | `service` | `minecraft-game-server` |
| `Environment` | `environment` | `dev` (allowed values: `dev`, `staging`, `prod`) |
| `Team` | `team` | `cloud-platform-team` |
| `Owner` | `owner` | `ana.torres@example.com` |

How they are applied:

- The provider's `default_tags` tags every resource that supports tagging.
- The Auto Scaling group gets explicit `tag` blocks, because `default_tags` does not apply to it.
- The launch template's `tag_specifications` tag the instances, EBS volumes and network interfaces that the group launches.
- Variable validation stops `terraform plan` if a tag is empty or the environment is not allowed.

## Deploy  

Requirements: Terraform 1.6 or later, and AWS credentials with permission to create the resources above.

```bash
cd video-game-server/terraform
cp terraform.tfvars.example terraform.tfvars   # set the tags and accept the EULA
terraform init
terraform plan
terraform apply
```

You must accept the [Minecraft EULA](https://aka.ms/MinecraftEULA) by setting `accept_minecraft_eula = true`. Terraform refuses to plan without it.

When the apply finishes, Terraform prints `server_address`. In Minecraft, open **Multiplayer > Add Server** and use that address. The first server needs 3 to 5 minutes to install Java, download the server and generate the world.

### Operate

```bash
# Shell on a server (no SSH key or open port 22 needed)
aws ssm start-session --target <instance-id>

# On the server (the same logs are also in CloudWatch, see Logging)
sudo journalctl -u minecraft -f                      # server log
sudo cat /var/log/player-metric.log                  # metric publisher
sudo cat /var/log/cloud-init-output.log              # bootstrap log
sudo systemctl status amazon-cloudwatch-agent        # log shipping
```

Changes to the startup script only reach new servers. To apply them to running servers, start an instance refresh in the Auto Scaling group. This replaces the servers, and their worlds, see Limitations.

To test scaling without players, lower `target_players_per_server` to 1 and connect with 2 clients.

### Destroy

```bash
terraform destroy
```

## Cost

These are approximate us-east-1 on-demand prices when the default settings run all the time:

| Item | Approx. per month |
|---|---|
| 1 × t3.medium | ~$30 per server |
| Network Load Balancer | ~$16 plus LCU usage |
| 20 GB gp3 per server | ~$1.60 per server |
| Public IPv4 addresses (NLB and servers) | ~$3.60 each |
| KMS key for logs | ~$1 |
| CloudWatch Logs | ~$0.50 per GB ingested plus ~$0.03 per GB stored; usually under $1 for a small server |

Destroy the stack when nobody is playing.

## Limitations

- **Worlds are not backed up.** A world lives on its instance's root volume and is deleted when the instance is terminated, including on scale-in. Add an S3 backup job, or scale-in protection, before you keep anything important.
- **Scale-in can disconnect players.** The NLB waits 60 seconds (`deregistration_delay`) before it removes a server, but players still on it are disconnected.
- The player count is the number of TCP connections. It also includes server-list pings and NLB health checks that are open at the moment of measurement, so it can be slightly too high.
- The servers have public IPs so that they can download packages without a NAT gateway. Their security group only allows the game port.
- **No whitelist.** `server.properties` sets `white-list=false` explicitly, because newer Minecraft versions turn the whitelist on by default with an empty list, which rejects everyone. Any genuine Minecraft account (`online-mode=true`) can join; to limit who can connect, set `allowed_player_cidrs`.
