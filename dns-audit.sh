#!/usr/bin/env bash
# Audits foursailsapps.com DNS against the canonical record set in DNS.md.
#
#   ./dns-audit.sh                 # live check via dig (catches missing/wrong records)
#   ./dns-audit.sh export.txt      # also diff a Cloudflare export for EXTRA records
#                                  # (Cloudflare > DNS > Records > Import and Export > Export)
#
# dig alone cannot list a zone, so stale records only show up with the export.
set -u
D=foursailsapps.com
R=1.1.1.1
fail=0

expect() { # expect <label> <actual> <expected>
  if [ "$2" = "$3" ]; then echo "ok    $1"; else echo "WRONG $1"; echo "      got:  $2"; echo "      want: $3"; fail=1; fi
}
q() { dig +short "$1" "$2" @$R | sort | tr '\n' ' ' | sed 's/ $//'; }

expect "NS"       "$(q NS $D)"          "phil.ns.cloudflare.com. raquel.ns.cloudflare.com."
expect "A @"      "$(q A $D)"           "185.199.108.153 185.199.109.153 185.199.110.153 185.199.111.153"
expect "AAAA @"   "$(q AAAA $D)"        "2606:50c0:8000::153 2606:50c0:8001::153 2606:50c0:8002::153 2606:50c0:8003::153"
expect "CNAME www" "$(q CNAME www.$D)"  "foursailsapps.github.io."
expect "MX @"     "$(dig +short MX $D @$R | awk '{print $2}' | sort | tr '\n' ' ' | sed 's/ $//')" \
                                         "route1.mx.cloudflare.net. route2.mx.cloudflare.net. route3.mx.cloudflare.net."
expect "TXT @ (SPF only)" "$(q TXT $D)"  "\"v=spf1 include:_spf.mx.cloudflare.net ~all\""
expect "TXT _dmarc" "$(q TXT _dmarc.$D)" "\"v=DMARC1; p=none;\""

# Names that should NOT resolve (leftovers from Porkbun defaults or old setups).
for n in mail ftp pixie _github-pages-challenge-foursailapps _github-pages-challenge-foursailsapps; do
  r="$(dig +short "$n.$D" @$R | tr '\n' ' ')"
  if [ -n "$r" ]; then echo "EXTRA $n.$D -> $r"; fail=1; else echo "ok    no $n.$D"; fi
done

# Optional: diff a Cloudflare BIND export against the canonical set (ignores SOA/NS/comments/TTL).
if [ $# -ge 1 ]; then
  # Portable (BSD sed/awk): drop comments, SOA and NS rows; drop the TTL column if present;
  # collapse whitespace; strip the trailing dot on targets.
  norm() {
    grep -vE '^[[:space:]]*(;|$)' "$1" | grep -vE '[[:space:]](SOA|NS)[[:space:]]' \
      | awk '{ if ($2 ~ /^[0-9]+$/) $2 = ""; gsub(/[ \t]+/, " "); sub(/^ /, ""); sub(/ $/, ""); print }' \
      | sed -E 's/\.$//' | sort
  }
  canon=$(mktemp)
  cat > "$canon" <<EOF
$D. IN A 185.199.108.153
$D. IN A 185.199.109.153
$D. IN A 185.199.110.153
$D. IN A 185.199.111.153
$D. IN AAAA 2606:50c0:8000::153
$D. IN AAAA 2606:50c0:8001::153
$D. IN AAAA 2606:50c0:8002::153
$D. IN AAAA 2606:50c0:8003::153
www.$D. IN CNAME foursailsapps.github.io.
$D. IN MX 62 route3.mx.cloudflare.net.
$D. IN MX 70 route2.mx.cloudflare.net.
$D. IN MX 92 route1.mx.cloudflare.net.
$D. IN TXT "v=spf1 include:_spf.mx.cloudflare.net ~all"
_dmarc.$D. IN TXT "v=DMARC1; p=none;"
EOF
  echo "--- export diff (< canonical, > export) ---"
  if diff <(norm "$canon") <(norm "$1"); then echo "ok    export matches the canonical set"; else fail=1; fi
  rm -f "$canon"
fi

[ $fail -eq 0 ] && echo "ALL OK" || { echo "DIFFERENCES FOUND"; exit 1; }
