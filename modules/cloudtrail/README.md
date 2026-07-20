# CloudTrail module

A multi-region, encrypted CloudTrail with log file integrity validation, S3 data event
logging, CloudTrail Insights, and optional CloudWatch Logs streaming.

## Notes

- The trail bucket is provided by the `s3-logging` module; this module only attaches the
  bucket policy required for CloudTrail delivery.
- `kms_key_arn` must be a key whose policy grants `cloudtrail.amazonaws.com` (the KMS
  module's `cloudtrail` key does this).
- Insights for API call rate and API error rate are enabled.
