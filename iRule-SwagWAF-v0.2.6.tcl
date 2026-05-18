#--------------------------------------------------------------------------
# iRule Name: SwagWAF - v0.2.6
#--------------------------------------------------------------------------
# ABSTRACT: "Poor Man's WAF for AI API Endpoints"
# PURPOSE: Protect LLM/AI inference APIs from abuse, injection attacks, and
#          bot scraping while enforcing security best practices
# THEME: AI Infrastructure - Traffic management & security for AI workloads
# CREATED: 2026-03-10 FOR: AppWorld 2026 iRules Contest
# AUTHOR: Joe Negron <joe@logicwizards.nyc>
#--------------------------------------------------------------------------
# FEATURES:
# - Bot detection via rate limiting (sliding window, violation tracking)
# - Prompt injection pattern detection (AI-specific threat protection)
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
    # Prompt injection patterns (examples of common LLM jailbreak attempts)
    set static::injection_patterns {
        "ignore previous instructions"
        "disregard all prior"
        "forget everything"
        "system prompt"
        "you are now in developer mode"
        "<script>"
        "'; DROP TABLE"
        "UNION SELECT"
    }
   
    # === DEBUG LOGGING ===
    set static::debug 1
}

#--------------------------------------------------------------------------
# CLIENTSSL_HANDSHAKE - TLS Version Enforcement
#--------------------------------------------------------------------------
when CLIENTSSL_HANDSHAKE {
    if {$static::debug}{log local0. "<DEBUG>[IP::client_addr]:[TCP::client_port]:[virtual name]:== TLS VERSION CHECK"}
    if {[SSL::cipher version] ne "TLSv1.2" && [SSL::cipher version] ne "TLSv1.3"} {
        log local0. "REJECTED: Client [IP::client_addr] attempted insecure TLS version: [SSL::cipher version]"
        reject
        HTTP::respond 403 content "TLS 1.2 or higher required for AI API access"
    }
}

#--------------------------------------------------------------------------
# HTTP_REQUEST - Multi-Layer Protection
#--------------------------------------------------------------------------
when HTTP_REQUEST {
    set ip [IP::client_addr]
    set now [clock clicks -milliseconds]
    set window_start [expr {$now - $static::window_ms}]
 
    # === X-FORWARDED-FOR SANITIZATION ===
    if {$static::debug}{log local0. "<DEBUG>$ip:[TCP::client_port]:[virtual name]:== SANITIZING XFF"}
    HTTP::header remove x-forwarded-for
    HTTP::header insert x-forwarded-for [IP::remote_addr]
    HTTP::header remove X-Custom-XFF
    HTTP::header insert X-Custom-XFF [IP::remote_addr]
   
    # === CHECK IF IP IS BLOCKED ===
    if {[table lookup "block:$ip"] eq "1"} {
        if {$static::debug}{log local0. "BLOCKED: $ip (repeated abuse)"}
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
            log local0. "BLOCKED: $ip (violation threshold: $v)"
            HTTP::respond 429 content "{\n  \"error\": \"rate_limit_exceeded\",\n  \"message\": \"Blocked for repeated abuse\",\n  \"retry_after\": 600\n}" "Content-Type" "application/json"
            return
        }   
        log local0. "RATE_LIMITED: $ip (req_count: $req_count, violations: $v)"
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
  
    # Check for prompt injection patterns
    foreach pattern $static::injection_patterns {
        if {[string match -nocase "*$pattern*" $payload_lower]} {
            set ip [IP::client_addr]
            log local0. "INJECTION_ATTEMPT: $ip tried pattern: $pattern"
          
            # Increment violation counter (treat injection attempts seriously)
            set v [table incr "viol:$ip" 3]
            table timeout "viol:$ip" $static::violation_window_ms
          
            if {$v >= $static::violation_threshold} {
               table set "block:$ip" 1 $static::block_seconds
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
    if {$static::debug}{log local0. "<DEBUG>[IP::client_addr]:[TCP::client_port]:[virtual name]:== SANITIZING RESPONSE HEADERS"}
 
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
    if {$static::debug}{log local0. "<DEBUG>[IP::client_addr]:[TCP::client_port]:[virtual name]:== SECURING COOKIES"}
   
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