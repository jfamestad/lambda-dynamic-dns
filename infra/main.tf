terraform {
	backend "s3" {
		bucket	= "jdftfrs"
		key 	= "dev/aws/dnsupdater"
		region	= "us-west-2"
		encrypt = true
		profile = "dev-infra"
	}
}

provider "aws" {
	region	= "us-west-2"
	profile = "dev-infra"
}

#resource "aws_iam_user" "dnsupdater" {
#	name = "dnsupdater"
#}

#resource "aws_iam_group" "dnsupdater" {
#	name = "dnsupdater"
#}

resource "aws_iam_policy" "dnsupdater" {
	name = "dnsupdater"
	policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "route53:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "lambda_role" {
	name = "dnsupdater"
	assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "attach-lambda-policy" {
	name = "attach-lambda-role"
	roles = ["${aws_iam_role.lambda_role.id}"]
	policy_arn = "${aws_iam_policy.dnsupdater.arn}"
}

resource "aws_lambda_function" "dnsupdater" {
	function_name = "dnsupdater"
	role = "${aws_iam_role.lambda_role.arn}"
	handler = "dnsupdater.lambda_handler"
	runtime = "python3.7"
	filename = "../lambda/dnsupdater.zip"
}

resource "aws_api_gateway_rest_api" "famestad" {
	name = "dnsupdater"
	description = "bang this api to update a subdomain in famestad.xyz"
}

resource "aws_api_gateway_resource" "dnsupdater" {
	rest_api_id = "${aws_api_gateway_rest_api.famestad.id}"
	parent_id = "${aws_api_gateway_rest_api.famestad.root_resource_id}"
	path_part = "dnsupdater"
}

resource "aws_api_gateway_method" "dnsupdater" {
	rest_api_id = "${aws_api_gateway_rest_api.famestad.id}"
	resource_id = "${aws_api_gateway_resource.dnsupdater.id}"
	http_method = "POST"
	authorization = "NONE"
}

resource "aws_api_gateway_integration" "dnsupdater" {
  rest_api_id             = "${aws_api_gateway_rest_api.famestad.id}"
  resource_id             = "${aws_api_gateway_resource.dnsupdater.id}"
  http_method             = "${aws_api_gateway_method.dnsupdater.http_method}"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.dnsupdater.invoke_arn}"
}

resource "aws_lambda_permission" "apigw_lambda" {
	statement_id = "AllowExecutionFromAPIGateway"
	action = "lambda:InvokeFunction"
	function_name = "${aws_lambda_function.dnsupdater.arn}"
	principal = "apigateway.amazonaws.com"
	source_arn = "arn:aws:execute-api:us-west-2:715143918824:${aws_api_gateway_rest_api.famestad.id}/*/${aws_api_gateway_method.dnsupdater.http_method}/${aws_api_gateway_resource.dnsupdater.path_part}"
}

resource "aws_api_gateway_deployment" "dnsupdater" {
	rest_api_id = "${aws_api_gateway_rest_api.famestad.id}"
	stage_name = "test"
	depends_on = [
		"aws_api_gateway_resource.dnsupdater", 
		"aws_api_gateway_method.dnsupdater",
		"aws_api_gateway_integration.dnsupdater"
	]
}

resource "aws_api_gateway_method_settings" "dnsupdater" {
	rest_api_id = "${aws_api_gateway_rest_api.famestad.id}"
	stage_name = "${aws_api_gateway_deployment.dnsupdater.stage_name}"
	method_path = "*/*"
	settings {
		metrics_enabled = true
		logging_level = "INFO"
	}
}

resource "aws_iam_role" "cloudwatch_role" {
	name = "dnsupdater-logs"
	assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_api_gateway_account" "dnsupdater" {
	cloudwatch_role_arn = "${aws_iam_role.cloudwatch_role.arn}"
}

resource "aws_iam_policy_attachment" "attach-cloudwatch-policy" {
	name = "attach-cloudwatch-role"
	roles = ["${aws_iam_role.cloudwatch_role.id}"]
	policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}
