module "bootstrap" {
	source =  "github.com/build-on-aws/terraform-samples//modules/bootstrap-aws-account"
	state_file_aws_region =  "ca-central-1"
	state_file_bucket_name = "aws-archangelo-terraform"
}
