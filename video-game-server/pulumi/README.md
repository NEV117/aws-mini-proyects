# Deploy with Pulumi

Pulumi (TypeScript) version of the Minecraft server infrastructure in [`../terraform`](../terraform).
It follows the layout of Pulumi's
[AWS Serverless Application template](https://www.pulumi.com/dev/templates/serverless-application/aws/)
(`Pulumi.yaml`, `Pulumi.dev.yaml`, `index.ts`) and creates the same resources as the Terraform
version. See the [parent README](../README.md) for the architecture, scaling, logging, cost and
limitations.

| Terraform file | Section of `index.ts` |
|---|---|
| `variables.tf`, `locals.tf` | Configuration, Validation, Locals (defaults in `Pulumi.yaml`) |
| `versions.tf` | `aws.Provider` with `defaultTags` |
| `network.tf` | Network |
| `logging.tf` | Centralized logging |
| `iam.tf` | IAM for the game servers |
| `nlb.tf` | Load balancer |
| `compute.tf` | Compute, Horizontal scaling |
| `outputs.tf` | Outputs |

Notes:

- **Same bootstrap script.** The Pulumi program reads `../terraform/user_data.sh.tftpl` and fills
  it in using Terraform's `templatefile()` syntax, so both tools deploy the same script. Keep the two
  folders together.
- **Same resource names.** Names such as `minecraft-dev-asg` and `/minecraft/dev/server` are set
  explicitly, as in Terraform, because the bootstrap script and the scaling metric refer to them.
  Don't deploy the Terraform and Pulumi versions to the same account and region with the same
  `namePrefix` and `environment`: the names collide.
- **Validation.** The Terraform `validation` blocks are checks at the top of `index.ts`. `pulumi preview`
  stops with a list of every problem.
- **Config names.** Each Terraform variable is a camelCase config key, for example
  `accept_minecraft_eula` becomes `acceptMinecraftEula`.

## Deploy

Requirements: [Pulumi CLI](https://www.pulumi.com/docs/install/), Node.js 22 or later, and AWS
credentials with permission to create the resources.

```bash
cd video-game-server/pulumi
npm install
pulumi login                                # Pulumi Cloud, or `pulumi login --local`
pulumi stack init dev                       # uses Pulumi.dev.yaml (aws:region = us-east-1)
pulumi config set acceptMinecraftEula true  # https://aka.ms/MinecraftEULA
pulumi up
```

Optional config (defaults in `Pulumi.yaml`):

```bash
pulumi config set owner you@example.com
pulumi config set environment prod                          # dev, staging or prod
pulumi config set maxServers 6
pulumi config set --path 'allowedPlayerCidrs[0]' 203.0.113.10/32   # restrict who can join
pulumi config set enableVpcFlowLogs false
```

When `pulumi up` finishes, add the address from `pulumi stack output serverAddress` in Minecraft
under **Multiplayer > Add Server**. The first server needs 3 to 5 minutes to install Java, download
the server and generate the world.

```bash
pulumi stack output autoscalingGroupName
pulumi stack output logGroups
aws logs tail "$(pulumi stack output logGroups --json | jq -r .server)" --follow
```

## Destroy

```bash
pulumi destroy
pulumi stack rm dev
```
