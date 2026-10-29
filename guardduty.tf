resource "aws_guardduty_detector" "main" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

# High-severity findings (7.0+) are sent to the alerts SNS topic.
resource "aws_cloudwatch_event_rule" "guardduty_high" {
  name        = "khmd-eu-pd-guardduty-high"
  description = "GuardDuty findings with severity >= 7"
  event_pattern = jsonencode({
    source        = ["aws.guardduty"]
    "detail-type" = ["GuardDuty Finding"]
    detail        = { severity = [{ numeric = [">=", 7] }] }
  })
}

resource "aws_cloudwatch_event_target" "guardduty_sns" {
  rule = aws_cloudwatch_event_rule.guardduty_high.name
  arn  = aws_sns_topic.alerts.arn
}
