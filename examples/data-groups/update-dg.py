#!/usr/bin/env python3
# --------------------------------------------------------------------------
# SCRIPT: update-dg.py
# --------------------------------------------------------------------------
# ABSTRACT: Create or replace the dg_injection_phrase data group on a BIG-IP
#     via the iControl REST API. Parses dg_injection_phrase.conf (the single
#     source of truth) and pushes it as a complete replacement (PUT) or
#     initial create (POST).
#
# USAGE:
#     python3 update-dg.py <bigip-host> <username>
#
#     Password is prompted interactively — never passed as an argument.
#     Run from any directory; the conf file is located relative to this script.
#
# REQUIREMENTS: Python 3.6+ stdlib only (no pip installs needed).
#               BIG-IP v15+ ships Python 3.6; v14 ships Python 2 — use v15+.
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

DG_NAME   = "dg_injection_phrase"
PARTITION = "Common"
CONF_FILE = Path(__file__).parent / "dg_injection_phrase.conf"


def parse_conf(path):
    """
    Parse an ltm data-group internal conf snippet into REST record dicts.
    Matches:  "key" { data VALUE }
    Returns:  [{"name": key, "data": value}, ...]
    """
    pattern = re.compile(r'"([^"]+)"\s*\{\s*data\s+(\w+)\s*\}', re.DOTALL)
    records = [{"name": m.group(1), "data": m.group(2)}
               for m in pattern.finditer(path.read_text())]
    if not records:
        raise ValueError(f"No records parsed from {path}")
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
    if len(sys.argv) != 3:
        print(f"Usage: python3 {Path(sys.argv[0]).name} <bigip-host> <username>",
              file=sys.stderr)
        sys.exit(1)

    bigip, username = sys.argv[1], sys.argv[2]
    password = getpass.getpass(f"BIG-IP password for {username}@{bigip}: ")
    auth     = "Basic " + b64encode(f"{username}:{password}".encode()).decode()

    records = parse_conf(CONF_FILE)
    print(f"Parsed {len(records)} records from {CONF_FILE.name}")

    payload = {
        "name":      DG_NAME,
        "partition": PARTITION,
        "type":      "string",
        "records":   records,
    }

    dg_path = f"/mgmt/tm/ltm/data-group/internal/~{PARTITION}~{DG_NAME}"

    status, body = rest(bigip, auth, "PUT", dg_path, payload)
    if status == 404:
        print("Data group not found — creating...")
        status, body = rest(bigip, auth, "POST",
                            "/mgmt/tm/ltm/data-group/internal", payload)

    if 200 <= status < 300:
        print(f"OK (HTTP {status}): {DG_NAME} updated on {bigip} "
              f"({len(records)} records)")
    else:
        print(f"ERROR (HTTP {status}):", file=sys.stderr)
        print(json.dumps(body, indent=2), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
