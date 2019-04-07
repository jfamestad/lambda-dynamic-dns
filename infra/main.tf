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

resource "aws_iam_user" "dnsupdater" {
	name = "dnsupdater"
}

resource "aws_iam_group" "dnsupdater" {
	name = "dnsupdater"
}

resource "aws_iam_policy" "dnsupdater" {
	name = "dnaupdater"
	policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:Describe*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "lambda_role" {
	name = "dnsupdater_lambda"
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

resource "aws_lambda_function" "dnsupdater" {
	function_name = "dnsupdater"
	role = "${aws_iam_role.lambda_role.arn}"
	handler = "dnsupdater"
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
	authorization = "AWS_IAM"
}

resource "aws_api_gateway_integration" "dnsupdater" {
  rest_api_id             = "${aws_api_gateway_rest_api.famestad.id}"
  resource_id             = "${aws_api_gateway_resource.dnsupdater.id}"
  http_method             = "${aws_api_gateway_method.dnsupdater.http_method}"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:us-west-2:lambda:path/2015-03-31/functions/${aws_lambda_function.dnsupdater.arn}/invocations"
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.dnsupdater.arn}"
  principal     = "apigateway.amazonaws.com"

  source_arn = "arn:aws:execute-api:us-west-2:715143918824:${aws_api_gateway_rest_api.famestad.id}/*/${aws_api_gateway_method.dnsupdater.http_method}/${aws_api_gateway_resource.dnsupdater.path}"
}
