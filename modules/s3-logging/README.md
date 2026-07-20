# S3 logging module

A centralized, encrypted, versioned, access-logged S3 bucket for CloudTrail,
VPC Flow Logs, ALB access logs, and WAF logs. Public access is fully blocked
and a bucket policy denies insecure (non-TLS) transport and public ACLs.

> The bucket name is derived from `name_prefix`, region, and account ID, so it is
> globally unique. Override `name_prefix` per environment to avoid collisions.
