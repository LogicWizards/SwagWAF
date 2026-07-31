#!/usr/bin/env python3
# --------------------------------------------------------------------------
# SCRIPT: update-dg.py
# --------------------------------------------------------------------------
# ABSTRACT: Create or replace a SwagWAF data group on a BIG-IP via the iControl
#     REST API. Parses a .conf file (single source of truth) and pushes it as a
#     complete replacement (PUT) or initial create (POST). DG name and partition
#     are read from the conf file header — no hardcoding required.
#
# USAGE:
#     python3 update-dg.py <bigip-host> <username> [conf-file]
#
#     conf-file  Path to the ltm data-group conf file.
#                Defaults to dg_swagwaf_jailbreak_patterns.conf (sibling of this script).
#                Any dg_swagwaf_*.conf with a valid header works without code changes.
#
#     Password is prompted interactively — never passed as an argument.
#     Run from any directory; relative conf paths resolve from cwd.
#
# REQUIREMENTS: Python 3.6+ stdlib only (no pip installs needed).
#               BIG-IP v15+ ships Python 3.6; v14 ships Python 2 — use v15+.
#
# WARNING: This script is intended for lab use and careful manual operation.
#     - TLS certificate verification is DISABLED (ssl.CERT_NONE). This is
#       acceptable for BIG-IP management interfaces using self-signed certs,
#       but means the connection is vulnerable to MITM on untrusted networks.
#       Only run this from a trusted management VLAN or jump host.
#     - There is no dry-run mode. A successful PUT/POST overwrites the live
#       data group immediately — no backup is taken beforehand.
#     - Not hardened for unattended CI/CD use. Review and add retry logic,
#       cert pinning, and pre-update backup before automating.
# --------------------------------------------------------------------------

import sys
import re
import json
import getpass
import urllib.request
import urllib.error
import ssl
from base64 import b64encode
from pathlib import Path

DEFAULT_CONF = Path(__file__).parent / "dg_swagwaf_jailbreak_patterns.conf"


def parse_dg_meta(path):
    """
    Extract partition, DG name, and type from the conf:
      ltm data-group internal /Common/dg_name {
        type string|ip
    Returns: (partition, dg_name, dg_type)
    """
    text = path.read_text()
    header = re.search(r'ltm data-group internal /([\w-]+)/([\S]+)\s*\{', text)
    dg_type = re.search(r'^\s*type\s+(string|ip)\s*$', text, re.MULTILINE)
    if not header:
        raise ValueError(f"Cannot determine DG name/partition from {path}")
    if not dg_type:
        raise ValueError(f"Cannot determine DG type from {path}")
    return header.group(1), header.group(2), dg_type.group(1)


def parse_conf(path):
    """
    Parse an ltm data-group internal conf snippet into REST record dicts.
    Matches quoted keys with quoted or unquoted data values.
    Returns:  [{"name": key, "data": value}, ...]
    """
    quoted = r'((?:\\.|[^"\\])*)'
    pattern = re.compile(
        rf'"{quoted}"\s*\{{\s*data\s+(?:"{quoted}"|([^\s}}]+))\s*\}}',
        re.DOTALL,
    )
    text = path.read_text()
    records_body = re.search(
        r'^\s*records\s*\{(?P<body>.*?)^\s*\}\s*\n\s*type\s+(?:string|ip)\s*$',
        text,
        re.MULTILINE | re.DOTALL,
    )
    if not records_body:
        raise ValueError(f"Cannot isolate records block from {path}")

    body = records_body.group("body")

    def has_unparsed_content(gap):
        return any(
            line.strip() and not line.lstrip().startswith("#")
            for line in gap.splitlines()
        )

    records = []
    position = 0
    for match in pattern.finditer(body):
        if has_unparsed_content(body[position:match.start()]):
            raise ValueError(f"Unparsed content in {path}; refusing destructive replacement")
        name = json.loads(f'"{match.group(1)}"')
        data = (
            json.loads(f'"{match.group(2)}"')
            if match.group(2) is not None
            else match.group(3)
        )
        records.append({"name": name, "data": data})
        position = match.end()
    if not records:
        raise ValueError(f"No records parsed from {path}")
    if has_unparsed_content(body[position:]):
        raise ValueError(f"Unparsed content in {path}; refusing destructive replacement")
    names = [record["name"] for record in records]
    if len(names) != len(set(names)):
        raise ValueError(f"Duplicate record names in {path}; refusing destructive replacement")
    return records


def rest(bigip, auth_header, method, path, body=None):
    """Execute a single iControl REST request. Returns (status_code, body_dict)."""
    url  = f"https://{bigip}{path}"
    data = json.dumps(body).encode() if body else None
    req  = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", auth_header)
    req.add_header("Content-Type", "application/json")

    # BIG-IP management interfaces commonly use self-signed certs
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode    = ssl.CERT_NONE

    try:
        with urllib.request.urlopen(req, context=ctx) as resp:
            return resp.status, json.loads(resp.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


def main():
    if len(sys.argv) not in (3, 4):
        print(f"Usage: python3 {Path(sys.argv[0]).name} <bigip-host> <username> [conf-file]",
              file=sys.stderr)
        sys.exit(1)

    bigip, username = sys.argv[1], sys.argv[2]
    conf_file = Path(sys.argv[3]) if len(sys.argv) == 4 else DEFAULT_CONF

    if not conf_file.exists():
        print(f"ERROR: conf file not found: {conf_file}", file=sys.stderr)
        sys.exit(1)

    partition, dg_name, dg_type = parse_dg_meta(conf_file)
    password = getpass.getpass(f"BIG-IP password for {username}@{bigip}: ")
    auth     = "Basic " + b64encode(f"{username}:{password}".encode()).decode()

    records = parse_conf(conf_file)
    print(f"Parsed {len(records)} records from {conf_file.name} ({dg_name})")

    payload = {
        "name":      dg_name,
        "partition": partition,
        "type":      dg_type,
        "records":   records,
    }

    dg_path = f"/mgmt/tm/ltm/data-group/internal/~{partition}~{dg_name}"

    status, body = rest(bigip, auth, "PUT", dg_path, payload)
    if status == 404:
        print("Data group not found — creating...")
        status, body = rest(bigip, auth, "POST",
                            "/mgmt/tm/ltm/data-group/internal", payload)

    if 200 <= status < 300:
        print(f"OK (HTTP {status}): {dg_name} updated on {bigip} "
              f"({len(records)} records)")
    else:
        print(f"ERROR (HTTP {status}):", file=sys.stderr)
        print(json.dumps(body, indent=2), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
