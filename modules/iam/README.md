# IAM module

Identity and administration primitives for the Zero Trust architecture.

## Resources

- **Break-glass role**: an emergency role with `AdministratorAccess` attached, but only
  assumable via `AssumeRole` with `aws:MultiFactorAuthPresent=true` and a short MFA age,
  from a configurable list of trusted principals. No long-lived credential is created.
- **Workload permission boundary**: a managed policy workload roles can attach to enforce
  no public IPs, no disabling of encryption, and no IAM privilege escalation.
- **Example SCP**: a policy document (output as JSON) that denies insecure S3 writes and
  public RDS. Apply it in your organization manually; this module does not create an org.

## Identity Center

AWS IAM Identity Center is the preferred workforce access method and is **documented only**
in this reference architecture (it requires an organization that is out of scope to create
here). See `docs/security-controls.md` and `docs/operations.md` for the recommended
permission sets and just-in-time elevation flow.
