module "budget_billing_alert" {
    source = "github.com/build-on-aws/terraform-samples//modules/aws-billing-budget-notification"

    budget_email_address = "felipe.archangelo@gmail.com"

    budget_alert_amount               = 10
    budget_alert_currency             = "USD"
    budget_alert_threshold_percentage = 75
}
