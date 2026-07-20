"""
Static security-invariant tests for the aws-zero-trust-reference-architecture repo.

These tests do NOT call AWS and do NOT run `terraform plan`. They statically scan the
Terraform source to assert the Zero Trust invariants the project promises:

  * No inbound SSH (22) or RDP (3389) rules anywhere
  * RDS is not publicly accessible
  * Application workloads receive no public IP addresses
  * S3 public access block is enabled (all four flags)
  * Encryption is enabled at rest (RDS, S3, KMS rotation)
  * VPC Flow Logs are enabled
  * CloudTrail is enabled (enable_logging = true)
  * Required tags are present on key resources
  * Outputs never expose secret values

Run with:  python -m pytest tests/python -q
"""
import re
import pathlib
import pytest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def tf_files():
    return list(ROOT.rglob("*.tf"))


def read(p):
    return p.read_text(encoding="utf-8")


def all_text():
    return "\n".join(read(p) for p in tf_files())


def find_resource_blocks(text, rtype):
    """Yield (file_path, body) for every `resource "rtype" "..." { ... }` block."""
    pattern = re.compile(
        r'resource\s+"' + re.escape(rtype) + r'"\s+"[^"]+"\s+\{(.*?)\n\}',
        re.DOTALL,
    )
    for p in tf_files():
        for m in pattern.finditer(read(p)):
            yield p, m.group(1)


def var_default(file_path, varname):
    body = file_path.read_text(encoding="utf-8")
    m = re.search(
        r'variable\s+"' + re.escape(varname) + r'"\s+\{(?:(?!\n\}).)*?default\s*=\s*(\S+)',
        body, re.DOTALL,
    )
    return m.group(1) if m else None


def test_no_ssh_or_rdp_ingress():
    offenders = []
    for p in tf_files():
        body = read(p)
        for m in re.finditer(
            r'(ingress|resource\s+"aws_vpc_security_group_ingress_rule"\s+"[^"]+")\s*\{(?:(?!\n\}).)*?from_port\s*=\s*(\d+)',
            body, re.DOTALL,
        ):
            port = int(m.group(2))
            if port in (22, 3389):
                offenders.append((str(p.relative_to(ROOT)), port))
    assert not offenders, f"SSH/RDP ingress found: {offenders}"


def test_rds_not_publicly_accessible():
    for p, body in find_resource_blocks(all_text(), "aws_db_instance"):
        m = re.search(r'publicly_accessible\s*=\s*(\S+)', body)
        assert m, "RDS instance must explicitly set publicly_accessible"
        assert m.group(1).rstrip().lower() != "true", f"RDS publicly_accessible=true in {p}"


def test_rds_module_enforces_private_default():
    rds_vars = (ROOT / "modules/rds/variables.tf").read_text(encoding="utf-8")
    assert "publicly_accessible" in rds_vars
    assert re.search(r'var\.publicly_accessible\s*==\s*false', rds_vars), \
        "rds module must validate publicly_accessible == false"


def test_app_workloads_no_public_ip():
    found_any = False
    for p, body in find_resource_blocks(all_text(), "aws_ecs_service"):
        found_any = True
        m = re.search(r'assign_public_ip\s*=\s*(\S+)', body)
        assert m, "ECS service must set assign_public_ip"
        assert m.group(1).lower() == "false", f"assign_public_ip != false in {p}"
    assert found_any, "Expected at least one aws_ecs_service to assert on"


def test_subnets_do_not_map_public_ip():
    for p, body in find_resource_blocks(all_text(), "aws_subnet"):
        if 'tier = "app"' in body or 'tier = "data"' in body:
            m = re.search(r'map_public_ip_on_launch\s*=\s*(\S+)', body)
            if m:
                assert m.group(1).lower() == "false", f"Public IP mapped on a private/data subnet in {p}"


def test_s3_public_access_block_enabled():
    found = False
    for p, body in find_resource_blocks(all_text(), "aws_s3_bucket_public_access_block"):
        found = True
        for flag in ["block_public_acls", "block_public_policy", "ignore_public_acls", "restrict_public_buckets"]:
            m = re.search(rf'{flag}\s*=\s*(\S+)', body)
            assert m and m.group(1).lower() == "true", f"{flag} not true in {p}"
    assert found, "No aws_s3_bucket_public_access_block found"


def test_rds_storage_encrypted():
    for p, body in find_resource_blocks(all_text(), "aws_db_instance"):
        m = re.search(r'storage_encrypted\s*=\s*(\S+)', body)
        assert m and m.group(1).rstrip().lower() != "false", f"RDS storage_encrypted disabled in {p}"


def test_s3_sse_kms_enabled():
    blocks = list(find_resource_blocks(all_text(), "aws_s3_bucket_server_side_encryption_configuration"))
    assert blocks, "No S3 SSE configuration found"
    for p, body in blocks:
        assert "aws:kms" in body, f"S3 SSE must use KMS in {p}"


def test_kms_key_rotation_enabled():
    found = False
    for p, body in find_resource_blocks(all_text(), "aws_kms_key"):
        found = True
        m = re.search(r'enable_key_rotation\s*=\s*(\S+)', body)
        assert m, f"enable_key_rotation not set in {p}"
        val = m.group(1).rstrip()
        if val.startswith("var."):
            d = var_default(p.parent / "variables.tf", val[4:])
            assert d and d.lower() == "true", f"{val} default not true in {p.parent}"
        else:
            assert val.lower() == "true", f"KMS key rotation disabled in {p}"
    assert found, "No aws_kms_key found"


def test_vpc_flow_logs_enabled():
    blocks = list(find_resource_blocks(all_text(), "aws_flow_log"))
    assert blocks, "No aws_flow_log resource found"


def test_cloudtrail_enabled():
    for p, body in find_resource_blocks(all_text(), "aws_cloudtrail"):
        m = re.search(r'enable_logging\s*=\s*(\S+)', body)
        assert m and m.group(1).lower() == "true", f"CloudTrail enable_logging != true in {p}"


def test_required_tags_present():
    required = ["aws_vpc", "aws_lb", "aws_db_instance", "aws_ecs_service", "aws_s3_bucket"]
    for rtype in required:
        blocks = list(find_resource_blocks(all_text(), rtype))
        assert blocks, f"No {rtype} found to tag-check"
        for p, body in blocks:
            assert "tags" in body, f"{rtype} missing tags in {p}"


def test_no_plaintext_secrets_in_outputs():
    for p in (ROOT / "modules").rglob("outputs.tf"):
        body = read(p)
        for m in re.finditer(r'output\s+"([^"]+)"\s+\{(.*?)\n\}', body, re.DOTALL):
            name, obody = m.group(1), m.group(2)
            if re.search(r'(password|secret_value|secret_string)', obody, re.IGNORECASE):
                assert re.search(r'sensitive\s*=\s*true', obody), \
                    f"Output {name} in {p} exposes a secret without sensitive=true"


if __name__ == "__main__":
    raise SystemExit(pytest.main([str(pathlib.Path(__file__).parent), "-q"]))


def test_data_tier_has_no_default_route():
    """The isolated data route table must not contain a 0.0.0.0/0 default route."""
    net = (ROOT / "modules/network/main.tf").read_text(encoding="utf-8")
    m = re.search(r'resource\s+"aws_route_table"\s+"data"\s+\{(.*?)\n\}', net, re.DOTALL)
    assert m, "No aws_route_table.data found"
    body = m.group(1)
    assert not re.search(r'route\s*\{(?:(?!\n\}).)*?0\.0\.0\.0/0', body, re.DOTALL), \
        "Data tier route table must not have a default route to the internet"