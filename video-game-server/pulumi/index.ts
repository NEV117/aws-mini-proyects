import * as fs from "fs";
import * as path from "path";
import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";

// ---------------------------------------------------------------------------
// Configuration (defaults and types live in Pulumi.yaml)
// ---------------------------------------------------------------------------

const config = new pulumi.Config();
const region = aws.config.requireRegion();

const namePrefix = config.get("namePrefix") ?? "minecraft";

const service = config.get("service") ?? "minecraft-game-server";
const environment = config.get("environment") ?? "dev";
const team = config.get("team") ?? "cloud-platform-team";
const owner = config.get("owner") ?? "ana.torres@example.com";

const vpcCidr = config.get("vpcCidr") ?? "10.20.0.0/16";
const publicSubnetCidrs = config.getObject<string[]>("publicSubnetCidrs") ?? ["10.20.1.0/24", "10.20.2.0/24"];
const allowedPlayerCidrs = config.getObject<string[]>("allowedPlayerCidrs") ?? ["0.0.0.0/0"];

const acceptMinecraftEula = config.getBoolean("acceptMinecraftEula") ?? false;
const minecraftVersion = config.get("minecraftVersion") ?? "latest";
const serverPort = config.getNumber("serverPort") ?? 25565;
const maxPlayersPerServer = config.getNumber("maxPlayersPerServer") ?? 20;
const motd = config.get("motd") ?? "AWS Mini Projects Minecraft Server";
const difficulty = config.get("difficulty") ?? "normal";
const instanceType = config.get("instanceType") ?? "t3.medium";
const javaHeapMb = config.getNumber("javaHeapMb") ?? 3072;
const rootVolumeSizeGb = config.getNumber("rootVolumeSizeGb") ?? 20;

const logRetentionDays = config.getNumber("logRetentionDays") ?? 30;
const enableVpcFlowLogs = config.getBoolean("enableVpcFlowLogs") ?? true;

const minServers = config.getNumber("minServers") ?? 1;
const maxServers = config.getNumber("maxServers") ?? 4;
const desiredServers = config.getNumber("desiredServers") ?? 1;
const targetPlayersPerServer = config.getNumber("targetPlayersPerServer") ?? 10;
const targetCpuPercent = config.getNumber("targetCpuPercent") ?? 70;

// ---------------------------------------------------------------------------
// Validation (same rules as the Terraform variable validation blocks)
// ---------------------------------------------------------------------------

const errors: string[] = [];
for (const [tag, value] of Object.entries({ Service: service, Team: team, Owner: owner })) {
    if (value.trim().length === 0) errors.push(`The ${tag} tag must not be empty.`);
}
if (!["dev", "staging", "prod"].includes(environment)) {
    errors.push("environment must be one of: dev, staging, prod.");
}
if (publicSubnetCidrs.length < 2) {
    errors.push("Provide at least two publicSubnetCidrs so the servers span two Availability Zones.");
}
if (!acceptMinecraftEula) {
    errors.push("Run `pulumi config set acceptMinecraftEula true` to confirm you accept the Minecraft EULA (https://aka.ms/MinecraftEULA).");
}
if (!["peaceful", "easy", "normal", "hard"].includes(difficulty)) {
    errors.push("difficulty must be one of: peaceful, easy, normal, hard.");
}
const validRetention = [0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653];
if (!validRetention.includes(logRetentionDays)) {
    errors.push("logRetentionDays must be a value CloudWatch Logs supports, for example 7, 30, 90 or 365.");
}
if (errors.length > 0) {
    throw new Error(`Invalid configuration:\n  - ${errors.join("\n  - ")}`);
}

// ---------------------------------------------------------------------------
// Locals
// ---------------------------------------------------------------------------

// Compliance tags required on every resource.
const commonTags = { Service: service, Environment: environment, Team: team, Owner: owner };

const name = `${namePrefix}-${environment}`;
const asgName = `${name}-asg`;

// Custom CloudWatch metric the servers publish.
const metricNamespace = "MinecraftServer";
const metricName = "PlayersOnline";

// CloudWatch log groups the agent on each server writes to.
const serverLogGroups = {
    server: `/${namePrefix}/${environment}/server`,
    bootstrap: `/${namePrefix}/${environment}/bootstrap`,
    player_metric: `/${namePrefix}/${environment}/player-metric`,
};

// Compliance tags on every resource that supports tagging. Auto Scaling groups
// are the exception: they get explicit tags below, and the launch template tags
// the instances, volumes and network interfaces.
const provider = new aws.Provider("aws", { region, defaultTags: { tags: commonTags } });
const opts: pulumi.CustomResourceOptions = { provider };
const invokeOpts: pulumi.InvokeOptions = { provider };

const callerIdentity = aws.getCallerIdentityOutput({}, invokeOpts);
const accountId = callerIdentity.accountId;

// ---------------------------------------------------------------------------
// Network
//
// Public subnets only (no NAT gateway) to keep the project cheap. The instances
// get public IPs so they can download Java and the server jar, but the security
// group only opens the game port.
// ---------------------------------------------------------------------------

const azs = aws.getAvailabilityZonesOutput({ state: "available" }, invokeOpts);

const vpc = new aws.ec2.Vpc("main", {
    cidrBlock: vpcCidr,
    enableDnsSupport: true,
    enableDnsHostnames: true,
    tags: { Name: `${name}-vpc` },
}, opts);

const igw = new aws.ec2.InternetGateway("main", {
    vpcId: vpc.id,
    tags: { Name: `${name}-igw` },
}, opts);

const publicSubnets = publicSubnetCidrs.map((cidr, i) => new aws.ec2.Subnet(`public-${i + 1}`, {
    vpcId: vpc.id,
    cidrBlock: cidr,
    availabilityZone: azs.names[i],
    mapPublicIpOnLaunch: true,
    tags: { Name: `${name}-public-${i + 1}` },
}, opts));
const publicSubnetIds = publicSubnets.map(s => s.id);

const publicRouteTable = new aws.ec2.RouteTable("public", {
    vpcId: vpc.id,
    routes: [{ cidrBlock: "0.0.0.0/0", gatewayId: igw.id }],
    tags: { Name: `${name}-public-rt` },
}, opts);

publicSubnets.forEach((subnet, i) => new aws.ec2.RouteTableAssociation(`public-${i + 1}`, {
    subnetId: subnet.id,
    routeTableId: publicRouteTable.id,
}, opts));

const serverSg = new aws.ec2.SecurityGroup("server", {
    name: `${name}-server-sg`,
    description: "Minecraft game servers",
    vpcId: vpc.id,
    tags: { Name: `${name}-server-sg` },
}, opts);

// The NLB keeps the client's IP, so players' addresses must be allowed here.
allowedPlayerCidrs.forEach(cidr => new aws.vpc.SecurityGroupIngressRule(`players-${cidr}`, {
    securityGroupId: serverSg.id,
    description: "Minecraft players",
    ipProtocol: "tcp",
    fromPort: serverPort,
    toPort: serverPort,
    cidrIpv4: cidr,
}, opts));

// NLB health checks come from the load balancer's private IPs inside the VPC.
new aws.vpc.SecurityGroupIngressRule("nlb-health-check", {
    securityGroupId: serverSg.id,
    description: "NLB health checks",
    ipProtocol: "tcp",
    fromPort: serverPort,
    toPort: serverPort,
    cidrIpv4: vpc.cidrBlock,
}, opts);

new aws.vpc.SecurityGroupEgressRule("all", {
    securityGroupId: serverSg.id,
    description: "Outbound for package installs, server download and CloudWatch",
    ipProtocol: "-1",
    cidrIpv4: "0.0.0.0/0",
}, opts);

// ---------------------------------------------------------------------------
// Centralized logging
//
// - Server logs (Minecraft, bootstrap, player metric) are shipped by the
//   CloudWatch agent on each instance, one log stream per instance ID, so they
//   survive scale-in and instance replacement.
// - VPC Flow Logs record the network traffic to and from the servers.
// - All log groups are encrypted with a customer managed KMS key and expire
//   after logRetentionDays.
// ---------------------------------------------------------------------------

const logsKey = new aws.kms.Key("logs", {
    description: `Encrypts the ${name} CloudWatch log groups`,
    deletionWindowInDays: 7,
    enableKeyRotation: true,
    policy: accountId.apply(account => JSON.stringify({
        Version: "2012-10-17",
        Statement: [
            {
                Sid: "AccountAdministration",
                Effect: "Allow",
                Principal: { AWS: `arn:aws:iam::${account}:root` },
                Action: "kms:*",
                Resource: "*",
            },
            {
                Sid: "CloudWatchLogsUse",
                Effect: "Allow",
                Principal: { Service: `logs.${region}.amazonaws.com` },
                Action: [
                    "kms:Encrypt*",
                    "kms:Decrypt*",
                    "kms:ReEncrypt*",
                    "kms:GenerateDataKey*",
                    "kms:Describe*",
                ],
                Resource: "*",
                Condition: {
                    ArnLike: {
                        "kms:EncryptionContext:aws:logs:arn": `arn:aws:logs:${region}:${account}:log-group:*`,
                    },
                },
            },
        ],
    })),
}, opts);

new aws.kms.Alias("logs", {
    name: `alias/${name}-logs`,
    targetKeyId: logsKey.keyId,
}, opts);

// Log groups written by the CloudWatch agent on the servers.
const serverLogGroupResources = Object.fromEntries(
    Object.entries(serverLogGroups).map(([key, logGroupName]) => [key, new aws.cloudwatch.LogGroup(`server-${key}`, {
        name: logGroupName,
        retentionInDays: logRetentionDays,
        kmsKeyId: logsKey.arn,
    }, opts)]),
) as Record<keyof typeof serverLogGroups, aws.cloudwatch.LogGroup>;

// VPC Flow Logs
let vpcFlowLogGroup: aws.cloudwatch.LogGroup | undefined;
if (enableVpcFlowLogs) {
    vpcFlowLogGroup = new aws.cloudwatch.LogGroup("vpc-flow", {
        name: `/${namePrefix}/${environment}/vpc-flow`,
        retentionInDays: logRetentionDays,
        kmsKeyId: logsKey.arn,
    }, opts);

    const vpcFlowRole = new aws.iam.Role("vpc-flow", {
        name: `${name}-vpc-flow-logs-role`,
        assumeRolePolicy: accountId.apply(account => JSON.stringify({
            Version: "2012-10-17",
            Statement: [{
                Effect: "Allow",
                Principal: { Service: "vpc-flow-logs.amazonaws.com" },
                Action: "sts:AssumeRole",
                Condition: { StringEquals: { "aws:SourceAccount": account } },
            }],
        })),
    }, opts);

    const vpcFlowPolicy = new aws.iam.RolePolicy("vpc-flow", {
        name: `${name}-vpc-flow-logs`,
        role: vpcFlowRole.id,
        policy: vpcFlowLogGroup.arn.apply(arn => JSON.stringify({
            Version: "2012-10-17",
            Statement: [{
                Effect: "Allow",
                Action: [
                    "logs:CreateLogStream",
                    "logs:PutLogEvents",
                    "logs:DescribeLogGroups",
                    "logs:DescribeLogStreams",
                ],
                Resource: [arn, `${arn}:*`],
            }],
        })),
    }, opts);

    new aws.ec2.FlowLog("vpc", {
        vpcId: vpc.id,
        trafficType: "ALL",
        logDestinationType: "cloud-watch-logs",
        logDestination: vpcFlowLogGroup.arn,
        iamRoleArn: vpcFlowRole.arn,
        maxAggregationInterval: 60,
        tags: { Name: `${name}-vpc-flow-log` },
    }, { ...opts, dependsOn: [vpcFlowPolicy] });
}

// ---------------------------------------------------------------------------
// IAM for the game servers
// ---------------------------------------------------------------------------

const serverRole = new aws.iam.Role("server", {
    name: `${name}-server-role`,
    assumeRolePolicy: aws.iam.assumeRolePolicyForPrincipal({ Service: "ec2.amazonaws.com" }),
}, opts);

// Shell access through SSM Session Manager instead of opening SSH.
new aws.iam.RolePolicyAttachment("ssm", {
    role: serverRole.name,
    policyArn: aws.iam.ManagedPolicy.AmazonSSMManagedInstanceCore,
}, opts);

// Lets each server publish its player count, limited to our metric namespace.
new aws.iam.RolePolicy("player-metric", {
    name: `${name}-player-metric`,
    role: serverRole.id,
    policy: JSON.stringify({
        Version: "2012-10-17",
        Statement: [{
            Effect: "Allow",
            Action: "cloudwatch:PutMetricData",
            Resource: "*",
            Condition: { StringEquals: { "cloudwatch:namespace": metricNamespace } },
        }],
    }),
}, opts);

// Lets the CloudWatch agent write to the server log groups only.
new aws.iam.RolePolicy("server-logs", {
    name: `${name}-server-logs`,
    role: serverRole.id,
    policy: pulumi.all(Object.values(serverLogGroupResources).map(g => g.arn)).apply(arns => JSON.stringify({
        Version: "2012-10-17",
        Statement: [{
            Effect: "Allow",
            Action: ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"],
            Resource: arns.flatMap(arn => [arn, `${arn}:*`]),
        }],
    })),
}, opts);

const instanceProfile = new aws.iam.InstanceProfile("server", {
    name: `${name}-server-profile`,
    role: serverRole.name,
}, opts);

// ---------------------------------------------------------------------------
// Load balancer
//
// One public address for players. The NLB spreads new connections across the
// servers in the Auto Scaling group.
// ---------------------------------------------------------------------------

const nlb = new aws.lb.LoadBalancer("game", {
    name: `${name}-nlb`,
    loadBalancerType: "network",
    internal: false,
    subnets: publicSubnetIds,
    enableCrossZoneLoadBalancing: true,
}, opts);

const targetGroup = new aws.lb.TargetGroup("game", {
    name: `${name}-tg`,
    port: serverPort,
    protocol: "TCP",
    vpcId: vpc.id,
    targetType: "instance",
    // Give players time to finish before an instance is removed.
    deregistrationDelay: 60,
    // Each server has its own world, so a player who reconnects should land on
    // the same server.
    stickiness: { enabled: true, type: "source_ip" },
    healthCheck: {
        protocol: "TCP",
        port: "traffic-port",
        interval: 30,
        healthyThreshold: 3,
        unhealthyThreshold: 3,
    },
}, opts);

new aws.lb.Listener("game", {
    loadBalancerArn: nlb.arn,
    port: serverPort,
    protocol: "TCP",
    defaultActions: [{ type: "forward", targetGroupArn: targetGroup.arn }],
}, opts);

// ---------------------------------------------------------------------------
// Compute
// ---------------------------------------------------------------------------

const ami = aws.ssm.getParameterOutput({
    name: "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64",
}, invokeOpts);

// The bootstrap script is shared with the Terraform template, so it is rendered
// with Terraform's templatefile() rules: ${key} is replaced, $${ becomes ${.
function renderTemplate(file: string, vars: Record<string, string | number>): string {
    const text = fs.readFileSync(file, "utf8");
    return text.replace(/\$\$\{|\$\{(\w+)\}/g, (match, key?: string) => {
        if (key === undefined) return "${";
        if (!(key in vars)) throw new Error(`${file}: no value for template variable "${key}"`);
        return String(vars[key]);
    });
}

// Referencing the log group resources makes them exist before any server starts.
const userData = pulumi
    .all([
        serverLogGroupResources.server.name,
        serverLogGroupResources.bootstrap.name,
        serverLogGroupResources.player_metric.name,
    ])
    .apply(([serverLogGroup, bootstrapLogGroup, playerMetricLogGroup]) => {
        const script = renderTemplate(path.join(__dirname, "..", "terraform", "user_data.sh.tftpl"), {
            minecraft_version: minecraftVersion,
            server_port: serverPort,
            max_players: maxPlayersPerServer,
            motd,
            difficulty,
            java_heap_mb: javaHeapMb,
            asg_name: asgName,
            metric_namespace: metricNamespace,
            metric_name: metricName,
            server_log_group: serverLogGroup,
            bootstrap_log_group: bootstrapLogGroup,
            player_metric_log_group: playerMetricLogGroup,
        });
        return Buffer.from(script).toString("base64");
    });

// Instances and volumes launched by the ASG do not get provider defaultTags,
// so the compliance tags are set here explicitly.
const launchTemplate = new aws.ec2.LaunchTemplate("server", {
    namePrefix: `${name}-lt-`,
    imageId: ami.value,
    instanceType,
    iamInstanceProfile: { arn: instanceProfile.arn },
    vpcSecurityGroupIds: [serverSg.id],
    // Require IMDSv2.
    metadataOptions: {
        httpEndpoint: "enabled",
        httpTokens: "required",
        httpPutResponseHopLimit: 1,
    },
    blockDeviceMappings: [{
        deviceName: "/dev/xvda",
        ebs: {
            volumeSize: rootVolumeSizeGb,
            volumeType: "gp3",
            encrypted: "true",
            deleteOnTermination: "true",
        },
    }],
    userData,
    tagSpecifications: [
        { resourceType: "instance", tags: { ...commonTags, Name: `${name}-server` } },
        { resourceType: "volume", tags: { ...commonTags, Name: `${name}-server-volume` } },
        { resourceType: "network-interface", tags: { ...commonTags, Name: `${name}-server-eni` } },
    ],
}, opts);

const asg = new aws.autoscaling.Group("server", {
    name: asgName,
    minSize: minServers,
    maxSize: maxServers,
    desiredCapacity: desiredServers,
    vpcZoneIdentifiers: publicSubnetIds,
    targetGroupArns: [targetGroup.arn],
    // Replace servers that stop answering on the game port.
    healthCheckType: "ELB",
    healthCheckGracePeriod: 300,
    // Minecraft needs a few minutes to install and generate the world before its
    // metrics are meaningful.
    defaultInstanceWarmup: 300,
    launchTemplate: {
        id: launchTemplate.id,
        version: launchTemplate.latestVersion.apply(v => `${v}`),
    },
    enabledMetrics: ["GroupDesiredCapacity", "GroupInServiceInstances", "GroupTotalInstances"],
    // Provider defaultTags do not apply to Auto Scaling groups.
    tags: Object.entries({ ...commonTags, Name: `${name}-server` }).map(([key, value]) => ({
        key,
        value,
        propagateAtLaunch: false, // the launch template already tags instances
    })),
}, {
    ...opts,
    // Let the scaling policies change capacity without Pulumi resetting it.
    ignoreChanges: ["desiredCapacity"],
});

// ---------------------------------------------------------------------------
// Horizontal scaling
//
// Two target tracking policies. The group scales out when either one is above
// its target, and scales in only when both are below.
// ---------------------------------------------------------------------------

// Players per server, published every minute by each instance (see user data).
new aws.autoscaling.Policy("players", {
    name: `${name}-players-per-server`,
    autoscalingGroupName: asg.name,
    policyType: "TargetTrackingScaling",
    targetTrackingConfiguration: {
        targetValue: targetPlayersPerServer,
        customizedMetricSpecification: {
            namespace: metricNamespace,
            metricName,
            statistic: "Average",
            unit: "Count",
            metricDimensions: [{ name: "AutoScalingGroupName", value: asg.name }],
        },
    },
}, opts);

// CPU, as a fallback when a few players load many chunks.
new aws.autoscaling.Policy("cpu", {
    name: `${name}-cpu`,
    autoscalingGroupName: asg.name,
    policyType: "TargetTrackingScaling",
    targetTrackingConfiguration: {
        targetValue: targetCpuPercent,
        predefinedMetricSpecification: { predefinedMetricType: "ASGAverageCPUUtilization" },
    },
}, opts);

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

/** Address to add in Minecraft under Multiplayer > Add Server. */
export const serverAddress = pulumi.interpolate`${nlb.dnsName}:${serverPort}`;
/** Name of the Auto Scaling group running the game servers. */
export const autoscalingGroupName = asg.name;
/** CloudWatch metric used for scaling. */
export const playerMetric = pulumi.interpolate`${metricNamespace}/${metricName} (AutoScalingGroupName=${asg.name})`;
/** CloudWatch log groups for the servers and the VPC. */
export const logGroups = {
    server: serverLogGroupResources.server.name,
    bootstrap: serverLogGroupResources.bootstrap.name,
    player_metric: serverLogGroupResources.player_metric.name,
    ...(vpcFlowLogGroup ? { vpc_flow: vpcFlowLogGroup.name } : {}),
};
/** Tags applied to every resource. */
export const complianceTags = commonTags;
