module "bootstrap" {
    source = "github.com/build-on-aws/terraform-samples//modules/bootstrap-aws-account"

    state_file_aws_region  = "us-east-2"
    state_file_bucket_name = "aws-archangelo-terraform"
}

module "bootstrap_cicd_aws_codebuild" {
    source = "github.com/build-on-aws/terraform-samples//modules/bootstrap-cicd-aws-codebuild"

    github_organization       = "fearchangelo"
    github_repository         = "aws-archangelo"
    aws_region                = "us-east-2"
    state_file_iam_policy_arn = module.bootstrap.state_file_iam_policy_arn

    codebuild_terraform_version = "1.9.7"
}

