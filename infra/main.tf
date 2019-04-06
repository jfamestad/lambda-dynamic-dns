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
