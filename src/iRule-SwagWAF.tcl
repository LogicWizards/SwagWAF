#--------------------------------------------------------------------------
# iRule Name: SwagWAF
# File:       iRule-SwagWAF.tcl  (version tracked via git tags, not filename)
#--------------------------------------------------------------------------
# ABSTRACT: "Poor Man's WAF Enhanced for AI/API Endpoints"
# PURPOSE: Protect LLM/AI inference APIs from abuse, injection attacks, and
#          bot scraping while enforcing security best practices
# THEME: AI Infrastructure - Traffic management & security for AI workloads
# VERSION: 0.3.7
# AUTHOR: Joe Negron <https://github.com/LogicWizards>
# REPO: https://github.com/LogicWizards/SwagWAF
# LICENSE: MIT (see LICENSE file in repo)
# CREATED: 260310 FOR: AppWorld 2026 iRules Contest
# UPDATED: 260708  BY: JN — BIG-IP v17.x compat: matches_regex removed;
#           - switched to class match contains (literal substring keys in DG);
#           - fixed class match -element -> -name; structured ISA security logging with XFF;
#           - removed DG auto-detect probe (01070151 unfixable from Tcl); DG mode is now opt-in flag;
#           - reverted: variable DG name bypasses link-time validation; auto-detect restored via catch
# UPDATED: 260709  BY: JN — structured SWAGWAF|TRACE| logging (replaced <DEBUG> positional format);
#           - v0.3.6: added dst=[IP::local_addr] to all log lines;
#           - v0.3.6: added client_xff= (pre-sanitization XFF); src!=client_xff = spoofing indicator
#           - v0.3.7: added src=IP:PORT and dst=IP:PORT format per ISA feedback (source/dest port for web server correlation)
#--------------------------------------------------------------------------
# FEATURES:
# - Bot detection via rate limiting (sliding window, violation tracking)
# - Prompt injection detection via dg_swagwaf_jailbreak_patterns data group (threat-level aware)
#     HIGH   -> 403 block + violation points (3)
#     MEDIUM -> 400 reject + violation point (1)
#     LOW    -> log only, allow through
#     Fallback: static hardcoded patterns if data group is not configured
# - TLS 1.2+ enforcement (secure AI API communications)
# - X-Forwarded-For sanitization (accurate client IP tracking)
# - Security header hardening (HSTS, cache control, MIME sniffing prevention)
# - Cookie security (Secure + HttpOnly flags)
# - JSON payload validation (AI API request inspection)
#--------------------------------------------------------------------------

when RULE_INIT {
    # === RATE LIMITING CONFIG (Bot Detection) ===
    set static::max_requests 10      ;# Max requests per window
    set static::window_ms 2000       ;# 2-second sliding window
    set static::violation_threshold 5 ;# Violations before block
    set static::violation_window_ms 30000 ;# 30s violation window
    set static::block_seconds 600    ;# 10 min block duration
   
    # === AI-SPECIFIC PROTECTION ===
    # Primary injection detection uses the dg_swagwaf_jailbreak_patterns data group (threat-level aware).
    # See examples/data-groups/dg_swagwaf_jailbreak_patterns.conf — that file is the ONLY place to
    # add/remove/re-tier phrases. Do NOT duplicate the full list here.
    #
    # The static list below is a minimal last-resort fallback for environments where the
    # data group has not been deployed yet. It is intentionally short and is NOT kept in
    # sync with the data group.
    set static::injection_patterns {
        "ignore previous instructions"
        "ignore delimiters"
        "ignore the above"
        "disregard previous instructions"
        "disregard delimiters"
        "disregard the above"
        "disregard all prior"
        "forget everything"
        "system prompt"
        "you are now in developer mode"
        "<script>"
        "'; DROP TABLE"
        "UNION SELECT"
    }

    # === DATA GROUP AUTO-DETECTION ===
    # DG name stored in a variable — BIG-IP only validates *literal* data group names at
    # VIP-assignment time. A variable reference bypasses that check, so the iRule applies
    # to a VIP with no DG deployed. Detection falls back to the static list automatically.
    # When the DG is deployed, re-trigger RULE_INIT:  tmsh modify ltm rule SwagWAF { }
    set static::dg_name "dg_swagwaf_jailbreak_patterns"
    if {[catch {class size $static::dg_name} dg_count]} {
        set static::dg_jailbreak_ready 0
        log local0. "SwagWAF: $static::dg_name not deployed — static fallback active (13 patterns)"
    } else {
        set static::dg_jailbreak_ready 1
        log local0. "SwagWAF: $static::dg_name loaded OK ($dg_count patterns)"
    }
   
    # === DEBUG LOGGING ===
    # QA MODE: debug=1 for ISA security log validation. Reset to 0 before production promotion.
    set static::debug 0  ;# 0 = production | 1 = QA/debug (verbose security logs)
}

#--------------------------------------------------------------------------
# CLIENTSSL_HANDSHAKE - TLS Version Enforcement
#--------------------------------------------------------------------------
when CLIENTSSL_HANDSHAKE {
    if {$static::debug} {log local0. "SWAGWAF|TRACE|src=[IP::client_addr]:[TCP::client_port]|dst=[IP::local_addr]:[TCP::local_port]|vip=[virtual name]|event=TLS_CHECK|tls_ver=[SSL::cipher version]"}
    if {[SSL::cipher version] ne "TLSv1.2" && [SSL::cipher version] ne "TLSv1.3"} {
        log local0. "SWAGWAF|TLS_REJECTED|src=[IP::client_addr]:[TCP::client_port]|dst=[IP::local_addr]:[TCP::local_port]|vip=[virtual name]|tls_ver=[SSL::cipher version]"
        reject
    }
}

#--------------------------------------------------------------------------
# HTTP_REQUEST - Multi-Layer Protection
#--------------------------------------------------------------------------
when HTTP_REQUEST {
    set ip [IP::client_addr]
    set dst [IP::local_addr]
    set sport [TCP::client_port]
    set dport [TCP::local_port]
    set now [clock clicks -milliseconds]
    set window_start [expr {$now - $static::window_ms}]
    # === X-FORWARDED-FOR SANITIZATION ===
    # Capture client-claimed XFF before overwriting — src != client_xff indicates spoofing attempt
    set client_xff [HTTP::header "x-forwarded-for"]
    if {$client_xff eq ""} { set client_xff "(none)" }
    HTTP::header remove x-forwarded-for
    HTTP::header insert x-forwarded-for [IP::remote_addr]
    HTTP::header remove X-Custom-XFF
    HTTP::header insert X-Custom-XFF [IP::remote_addr]
    set xff [HTTP::header "x-forwarded-for"]
    if {$static::debug} {log local0. "SWAGWAF|TRACE|src=$ip:$sport|xff=$xff|client_xff=$client_xff|dst=$dst:$dport|vip=[virtual name]|method=[HTTP::method]|uri=[HTTP::uri]|event=REQUEST"}
    # === CHECK IF IP IS BLOCKED ===
    if {[table lookup "block:$ip"] eq "1"} {
        log local0. "SWAGWAF|BLOCKED_REPEAT|src=$ip:$sport|xff=$xff|client_xff=$client_xff|dst=$dst:$dport|vip=[virtual name]|method=[HTTP::method]|uri=[HTTP::uri]"
        HTTP::respond 429 content "{\n  \"error\": \"rate_limit_exceeded\",\n  \"message\": \"Temporarily blocked for repeated abuse\",\n  \"retry_after\": 600\n}" "Content-Type" "application/json"
        return
    }
    # === CLEANUP OLD REQUEST TIMESTAMPS ===
    foreach ts [table keys -subtable "ts:$ip"] {
        if {$ts < $window_start} {
            table delete -subtable "ts:$ip" $ts
        }
    }
    # === COUNT REQUESTS IN CURRENT WINDOW ===
    set req_count [llength [table keys -subtable "ts:$ip"]]
    if {$req_count >= $static::max_requests} {
        # Record violation
        set v [table incr "viol:$ip"]
        table timeout "viol:$ip" $static::violation_window_ms
        if {$v >= $static::violation_threshold} {
            # Block IP temporarily
            table set "block:$ip" 1 $static::block_seconds
            log local0. "SWAGWAF|BLOCKED|src=$ip:$sport|xff=$xff|client_xff=$client_xff|dst=$dst:$dport|vip=[virtual name]|method=[HTTP::method]|uri=[HTTP::uri]|violations=$v"
            HTTP::respond 429 content "{\n  \"error\": \"rate_limit_exceeded\",\n  \"message\": \"Blocked for repeated abuse\",\n  \"retry_after\": 600\n}" "Content-Type" "application/json"
            return
        }
        log local0. "SWAGWAF|RATE_LIMITED|src=$ip:$sport|xff=$xff|client_xff=$client_xff|dst=$dst:$dport|vip=[virtual name]|method=[HTTP::method]|uri=[HTTP::uri]|req_count=$req_count|violations=$v"
        HTTP::respond 429 content "{\n  \"error\": \"rate_limit_exceeded\",\n  \"message\": \"Too many requests - slow down\",\n  \"retry_after\": 2\n}" "Content-Type" "application/json"
        return
    }
    # === LOG TIMESTAMP OF THIS REQUEST ===
    table set -subtable "ts:$ip" $now 1 $static::window_ms
    # === AI-SPECIFIC: PROMPT INJECTION DETECTION ===
    # Only inspect POST requests with JSON payload
    if {[HTTP::method] eq "POST" && [HTTP::header exists "Content-Type"] && [HTTP::header "Content-Type"] contains "application/json"} {
        if {[HTTP::header exists "Content-Length"] && [HTTP::header "Content-Length"] < 65536} {
            HTTP::collect [HTTP::header "Content-Length"]
        }
    }
}

#--------------------------------------------------------------------------
# HTTP_REQUEST_DATA - JSON Payload Inspection
#--------------------------------------------------------------------------
when HTTP_REQUEST_DATA {
    set payload [HTTP::payload]
    set payload_lower [string tolower $payload]
    set ip [IP::client_addr]
    set xff [HTTP::header "x-forwarded-for"]

    # === PRIMARY: Data Group-Based Injection Detection ===
    # DG name referenced via variable to bypass BIG-IP link-time validation.
    # class match -name returns the matched key; -value returns the threat level.
    # dg_jailbreak_ready confirmed at RULE_INIT — no catch needed here.
    if {$static::dg_jailbreak_ready} {
        set matched_phrase [class match -name -- $payload_lower contains $static::dg_name]
    } else {
        set matched_phrase ""
    }

    if {$matched_phrase ne ""} {
        set threat_level [class match -value -- $matched_phrase equals $static::dg_name]
        if {$threat_level eq ""} { set threat_level "HIGH" }

        log local0. "SWAGWAF|INJECTION_ATTEMPT|src=$ip:$sport|xff=$xff|client_xff=$client_xff|dst=$dst:$dport|vip=[virtual name]|method=[HTTP::method]|uri=[HTTP::uri]|phrase=\"$matched_phrase\"|threat=$threat_level"

        if {$threat_level eq "HIGH"} {
            set v [table incr "viol:$ip" 3]
            table timeout "viol:$ip" $static::violation_window_ms
            if {$v >= $static::violation_threshold} {
                table set "block:$ip" 1 $static::block_seconds
                log local0. "SWAGWAF|BLOCKED|src=$ip:$sport|xff=$xff|client_xff=$client_xff|dst=$dst:$dport|vip=[virtual name]|violations=$v|reason=injection_threshold"
                HTTP::respond 403 content "{\n  \"error\": \"forbidden\",\n  \"message\": \"Malicious payload detected\"\n}" "Content-Type" "application/json"
                return
            }
            HTTP::respond 403 content "{\n  \"error\": \"forbidden\",\n  \"message\": \"Request rejected by security policy\"\n}" "Content-Type" "application/json"
            return
        } elseif {$threat_level eq "MEDIUM"} {
            set v [table incr "viol:$ip" 1]
            table timeout "viol:$ip" $static::violation_window_ms
            HTTP::respond 400 content "{\n  \"error\": \"invalid_request\",\n  \"message\": \"Request rejected by security policy\"\n}" "Content-Type" "application/json"
            return
        } else {
            # LOW: always log — ISA wants visibility on all security signals regardless of debug mode
            log local0. "SWAGWAF|LOW_RISK|src=$ip:$sport|xff=$xff|client_xff=$client_xff|dst=$dst:$dport|vip=[virtual name]|method=[HTTP::method]|uri=[HTTP::uri]|phrase=\"$matched_phrase\""
            return
        }
    }

    # === FALLBACK: Static Pattern Check ===
    # Used when dg_swagwaf_jailbreak_patterns data group is not configured on this BIG-IP.
    foreach pattern $static::injection_patterns {
        if {[string match -nocase "*$pattern*" $payload_lower]} {
            log local0. "SWAGWAF|INJECTION_ATTEMPT|src=$ip:$sport|xff=$xff|client_xff=$client_xff|dst=$dst:$dport|vip=[virtual name]|method=[HTTP::method]|uri=[HTTP::uri]|phrase=\"$pattern\"|threat=HIGH|dg=static_fallback"
            set v [table incr "viol:$ip" 3]
            table timeout "viol:$ip" $static::violation_window_ms
            if {$v >= $static::violation_threshold} {
                table set "block:$ip" 1 $static::block_seconds
                log local0. "SWAGWAF|BLOCKED|src=$ip:$sport|xff=$xff|client_xff=$client_xff|dst=$dst:$dport|vip=[virtual name]|violations=$v|reason=injection_threshold|dg=static_fallback"
                HTTP::respond 403 content "{\n  \"error\": \"forbidden\",\n  \"message\": \"Malicious payload detected\"\n}" "Content-Type" "application/json"
                return
            }
            HTTP::respond 400 content "{\n  \"error\": \"invalid_request\",\n  \"message\": \"Request rejected by security policy\"\n}" "Content-Type" "application/json"
            return
        }
    }
}

#--------------------------------------------------------------------------
# HTTP_RESPONSE - Security Header Hardening
#--------------------------------------------------------------------------
when HTTP_RESPONSE {
    if {$static::debug} {log local0. "SWAGWAF|TRACE|src=[IP::client_addr]:$sport|dst=[IP::local_addr]:$dport|vip=[virtual name]|event=RESPONSE_HEADERS"}
 
    # Remove server fingerprinting headers
    HTTP::header remove "Server"
    HTTP::header remove "X-Powered-By"
    HTTP::header remove "X-AspNet-Version"
    HTTP::header remove "X-AspNetMvc-Version"
   
    # Enforce security headers
    HTTP::header remove "Cache-Control"
    HTTP::header remove "Strict-Transport-Security"
    HTTP::header remove "X-Content-Type-Options"
  
    HTTP::header insert "Strict-Transport-Security" "max-age=31536000; includeSubDomains"
    HTTP::header insert "Cache-Control" "no-store, no-cache, must-revalidate, proxy-revalidate"
    HTTP::header insert "X-Content-Type-Options" "nosniff"
   
    # === COOKIE HARDENING (Secure + HttpOnly) ===
    if {$static::debug} {log local0. "SWAGWAF|TRACE|src=[IP::client_addr]:$sport|dst=[IP::local_addr]:$dport|vip=[virtual name]|event=COOKIE_HARDENING"}
   
    # Use F5 native cookie security (faster than manual parsing)
    foreach cookieName [HTTP::cookie names] {
        HTTP::cookie secure $cookieName enable
    }
  
    # Add HttpOnly flag to all Set-Cookie headers
    set new_cookies {}
    foreach cookie [HTTP::header values "Set-Cookie"] {
        if { ![string match "*HttpOnly*" [string tolower $cookie]] } {
            set modified_cookie [string trimright $cookie ";"]
            append modified_cookie "; HttpOnly"
            lappend new_cookies $modified_cookie
        } else {
            lappend new_cookies $cookie
        }
    }
   
    # Apply secured cookies
    HTTP::header remove "Set-Cookie"
    foreach cookie $new_cookies {
        if { ![string match "*secure*" [string tolower $cookie]] } {
            HTTP::header insert "Set-Cookie" "$cookie; Secure"
        } else {
            HTTP::header insert "Set-Cookie" "$cookie"
        }
    }

}