resource "aws_iam_role" "server" {
  name = "${local.name}-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Shell access through SSM Session Manager instead of opening SSH.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Lets each server publish its player count, limited to our metric namespace.
resource "aws_iam_role_policy" "player_metric" {
  name = "${local.name}-player-metric"
  role = aws_iam_role.server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "cloudwatch:PutMetricData"
      Resource = "*"
      Condition = {
        StringEquals = { "cloudwatch:namespace" = local.metric_namespace }
      }
    }]
  })
}

# Lets the CloudWatch agent write to the server log groups only.
resource "aws_iam_role_policy" "server_logs" {
  name = "${local.name}-server-logs"
  role = aws_iam_role.server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams",
      ]
      Resource = flatten([
        for group in aws_cloudwatch_log_group.server : [group.arn, "${group.arn}:*"]
      ])
    }]
  })
}

resource "aws_iam_instance_profile" "server" {
  name = "${local.name}-server-profile"
  role = aws_iam_role.server.name
}
