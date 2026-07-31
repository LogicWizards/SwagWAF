# SwagWAF FAQ

```
# --------------------------------------------------------------------------
# NOTES:    FAQ.md
# --------------------------------------------------------------------------
# ABSTRACT: Operational answers for SwagWAF versions, data groups, trusted
#     sources, rate-limit state, BIG-IP compatibility, logging, and rollout.
# CREATED:  260730 BY: JN
# UPDATED:  260731 BY: Sol(GPT5.6)::Copilot:MAC-00
# VERSION:  0.3.8
# ARCHITECT: JN
# TECHLEAD: JN
# --------------------------------------------------------------------------
```

## What is the current version?

v0.3.8 is the latest published release. The `dev` branch contains post-release
hardening that has not yet been promoted or tagged.

## Which BIG-IP versions are supported?

The current direct QA evidence covers BIG-IP 17.5. v0.3.2 replaced the
`matches_regex` class operator removed in v17.x and changed optional data-group names
to variable references. Test the iRule on the exact target TMOS release before
production promotion; broader compatibility is an implementation goal, not verified
evidence from this repository.

## Are data groups required?

No. If `dg_swagwaf_jailbreak_patterns` is absent at `RULE_INIT`, the iRule uses its
13-pattern static fallback. If `dg_swagwaf_trusted_sources` is absent, normal rate
limiting applies to every source. The two optional data groups fail independently.

## What does a trusted source bypass?

Rate limiting only. TLS enforcement, XFF sanitation, prompt-injection inspection,
response hardening, and structured logging remain active. The trusted-source data
group is not a general WAF allowlist.

In v0.3.8, the forwarded XFF header is rewritten before reaching the backend, but the
client-submitted XFF and request URI are logged without field escaping. The `dev`
branch sanitizes those values before structured logging; the broader event-envelope
normalization remains SW-28 follow-up work.

## Should each iRule or application have its own trusted-source data group?

No. Every supported SwagWAF variant should consume the one canonical
`/Common/dg_swagwaf_trusted_sources` object. Per-rule copies create policy drift,
duplicate approvals, and inconsistent incident response.

## Can one data group include or nest another data group?

SwagWAF treats an internal data group as a flat policy object; record values are
metadata, not pointers to other groups. If several owners contribute entries, the
automation layer should validate and render their approved records into one canonical
union. Do not build copy-of-copy or nested exception lists on BIG-IP.

## Can trusted-source records be hosts and CIDRs?

Yes. The canonical group is `type ip`, so records may identify an individual host or a
network prefix. Each governed record should carry `owner`, `service`, `ticket`, and
`expires` metadata. Do not put secrets, pipes, quotes, or newlines in metadata values.

```text
"192.0.2.0/24" {
  data "owner=EXAMPLE;service=SYNTHETIC;ticket=CHG0123456;expires=2026-12-31"
}
```

## When does the iRule recognize a new or replaced data group?

Data-group readiness is probed in `RULE_INIT`. After deploying a previously absent
group, reinitialize the specific rule so the readiness flag is refreshed:

```bash
tmsh modify ltm rule /Common/ADMIN-SwagWAF { }
```

A normal record update to an already available group does not require a second policy
object. Confirm the startup log and matched behavior after every deployment.

## Why can a block outlive its expected duration?

Before v0.3.8, an ordinary `table lookup "block:$ip"` touched the entry on every retry.
A continuously retrying monitor could therefore renew the idle timeout indefinitely.
v0.3.8 uses `table lookup -notouch` so a blocked request cannot renew that timeout.

## Does raising `max_requests` clear an existing block?

No. Changing the threshold affects new request accounting; it does not delete existing
`block:<ip>` or `viol:<ip>` state. Reloading configuration re-runs `RULE_INIT` but also
does not prove that TMM table state was purged.

When a source matches the trusted-source policy, v0.3.8 deletes that source's block and
violation entries before continuing with the remaining WAF controls. For untrusted
sources, use a reviewed iRule-side operational mechanism or wait for verified expiry.

## Can generic iRule table state be shown or deleted with tmsh?

Do not rely on `show ltm table` or `delete ltm table all`; those are not valid generic
tmsh modules for arbitrary iRule `table` state. Preserve device output when diagnosing
state and validate any operational command against the target TMOS version or official
F5 documentation.

## Are all timeout values verified?

No. v0.3.8 preserves the BIG-IP 17.5 QA-pilot Tcl, where millisecond request-window
values are also passed to BIG-IP table idle-timeout arguments. The `-notouch` change
prevents blocked retries from renewing the block entry. The `dev` branch now separates
millisecond timestamp arithmetic from second-based table timeouts, but save/compile and
controlled expiry validation remain open. The HTTP `retry_after` value states configured
policy intent, not proof of observed expiry duration.

## What about the full and lite iRule variants?

The v0.3.8 POC changes only `/Common/ADMIN-SwagWAF`. The independently created
`/Common/Admin-SwagWAF_lite` remains unchanged until its owner and purpose are
confirmed. Continuing lite-rule throttle events are evidence for convergence, not a
reason to create a second exception list.

## How is a data group deployed?

The reference artifacts can be merged with tmsh on BIG-IP or pushed with the Python
iControl REST helper:

```bash
python3 examples/data-groups/update-dg.py <bigip-host> <username> \
  examples/data-groups/dg_swagwaf_trusted_sources.conf
```

The helper prompts for the password; never pass credentials as command arguments or
store them in data-group metadata. After deployment, read back the object, save the
configuration, and verify HA config sync.

## What should ISA see in logs?

Security events use `SWAGWAF|EVENT|key=value` records. Trusted matches emit
`SWAGWAF|TRUSTED_SOURCE` with source, matched host/CIDR, sanitized policy metadata,
XFF values, destination, VIP, method, URI, and `action=rate_limit_bypass`.

The original client-supplied XFF is captured as `client_xff` before SwagWAF replaces
the forwarded header with the TCP source. A `client_xff` value different from `src` is
an investigation signal, not proof by itself of malicious intent.

## If F5 syslog is forwarded to a SIEM, how can events be aggregated by hour to see if something is wrong?

For Sumo Logic, set the GUI time range to cover the desired before-and-after period,
then run this query. The GUI range selects which messages are searched; `timeslice 1h`
groups those messages into hourly buckets.

```text
_datatier=all AND "F5" AND "SWAGWAF"
| parse regex "Rule\s+(?<irule>\S+)\s+<[^>]+>:"
| parse regex "SWAGWAF\|(?<event>[^|]+)\|"
| timeslice 1h
| formatDate(_timeslice, "MM/dd-ha") as hour
| count by _timeslice, hour, irule, event
| sort by _timeslice asc, irule asc, _count desc
```

Keep `_timeslice` in the aggregation and sort even when displaying the friendlier
`hour` value. Sorting only the formatted label can produce alphabetical rather than
chronological results. While troubleshooting a parser, add `nodrop` after each `parse
regex` expression so unmatched messages remain visible.

The equivalent workflow in Splunk is `rex`, `bin _time span=1h`, and `stats count by
_time irule event`. In Datadog or Elastic, first extract `irule` and `event` from the
raw message with a log pipeline or ingest parser, then graph a count grouped by those
fields in one-hour intervals. Parser syntax and index names are deployment-specific;
confirm them against one raw forwarded message before saving a dashboard or alert.

A post-cutover interval containing only `TRUSTED_SOURCE` confirms that the iRule is
executing and trusted traffic is matching policy. It does not exercise or prove the
`TRACE`, `RATE_LIMITED`, `BLOCKED`, or `BLOCKED_REPEAT` paths. If ordinary traffic is
not expected during the observation window, run controlled QA tests from an untrusted
source and verify each expected event rather than treating an empty category as a
pass or failure.

For trusted-source post-deploy checks with SIEM-visible test identifiers, see the
[`tests` runbook](tests/README.md). It provides a zero-install curl example and a
standard-library Python suite that also works with pytest when pytest is available.

## How should self-service exceptions work?

An intake form or spreadsheet may collect requests, but it is not authoritative state.
Approved records should live in Git or an authoritative ServiceNow table, then AAP
should validate and reconcile the complete canonical data group. Production additions,
CIDR expansions, and cross-owner deletions require approval and audit evidence.

## How should rate limiting be tested?

Use an untrusted source in QA and send more than the configured threshold within the
configured window. v0.3.8 defaults to 100 requests per window, so old 12- or 15-request
examples do not exercise the limiter. A trusted source should instead produce
`SWAGWAF|TRUSTED_SOURCE` and no new rate-limit block.

The `$VIP` value may include a non-default HTTPS port, for example
`https://example.test:8443`. Avoid active burst tests against production VIPs.
