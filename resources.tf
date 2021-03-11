provider "aws" {
  profile = "igorfil-personal"
  region  = "us-west-2"
}

resource "aws_sqs_queue" "dlq" {
  name = "dlq"
}

resource "aws_sqs_queue" "email-queue" {
  name                       = "email-queue"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 86400
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue_policy" "test" {
  queue_url = aws_sqs_queue.email-queue.id

  policy = <<POLICY
{
"Version": "2012-10-17",
"Id": "sqspolicy",
"Statement": [
  {
    "Sid": "First",
    "Effect": "Allow",
    "Principal": "*",
    "Action": "sqs:SendMessage",
    "Resource": "${aws_sqs_queue.email-queue.arn}"
  }
]
}
POLICY
}

data "aws_iam_policy_document" "lambda_role_iam_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "emailer-lambda-role" {
  name               = "EmailerLambdaRole"
  assume_role_policy = data.aws_iam_policy_document.lambda_role_iam_policy.json
}

resource "aws_lambda_function" "emailer-lambda" {
  function_name    = "emailer-lambda"
  role             = aws_iam_role.emailer-lambda-role.arn
  handler          = "emailer.lambda_handler"
  filename         = "emailer-lambda.zip"
  source_code_hash = base64sha256(filebase64("emailer-lambda.zip"))
  runtime          = "python3.8"

  environment {
    variables = {
      SENDER = "Igor Fil (automated) <igor.v.fil.secondary@gmail.com>"
    }
  }
}

resource "aws_lambda_event_source_mapping" "sqs-email-lambda" {
  event_source_arn = aws_sqs_queue.email-queue.arn
  function_name    = aws_lambda_function.emailer-lambda.arn
  batch_size       = 1
  enabled          = true
}

resource "aws_iam_role_policy_attachment" "sqs-lambda-policy-attachment" {
  policy_arn = aws_iam_policy.lambda-sqs-policy.arn
  role       = aws_iam_role.emailer-lambda-role.name
}

resource "aws_iam_policy" "lambda-sqs-policy" {
  policy = data.aws_iam_policy_document.sqs-lambda-policy-doc.json
}

resource "aws_cloudwatch_log_group" "lambda-log-group" {
  name              = "/aws/lambda/${aws_lambda_function.emailer-lambda.function_name}"
  retention_in_days = 14
}

data "aws_iam_policy_document" "sqs-lambda-policy-doc" {
  statement {
    sid       = "AllowSQSPermissions"
    effect    = "Allow"
    resources = ["arn:aws:sqs:*"]

    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage",
    ]
  }

  statement {
    sid       = "AllowInvokingLambdas"
    effect    = "Allow"
    resources = ["arn:aws:lambda:us-west-2:*:function:*"]
    actions   = ["lambda:InvokeFunction"]
  }

  statement {
    sid       = "AllowWritingLogs"
    effect    = "Allow"
    resources = ["arn:aws:logs:us-west-2:*:log-group:/aws/lambda/*:*"]

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }

  statement {
    sid       = "AllowSendEmail"
    effect    = "Allow"
    resources = ["arn:aws:ses:us-west-2:*:*"]
    actions   = ["ses:SendEmail"]
  }
}