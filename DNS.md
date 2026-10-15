# DNS for foursailsapps.com (Porkbun registrar → Cloudflare DNS → GitHub Pages)

- Registrar: Porkbun. Only the nameservers are set there; all records live at Cloudflare.
- DNS + email: Cloudflare (Free plan). Email Routing catch-all forwards every address
  (`support@`, `privacy@`, each `<app>@`) to one inbox. No explicit aliases; add them only to
  route an address differently or to switch the catch-all to Drop if spam becomes a problem.
- Site: GitHub Pages from the `foursailsapps/foursails-site` repo. The repo contains `CNAME`
  (`foursailsapps.com`); the Pages custom domain was set via the API, never through the web UI
  (web changes create CNAME commits under a personal account).
- Spelling: the domain is `foursails**apps**.com` with the "s" after "sail", matching the studio
  name Four Sails. The GitHub org is `foursailsapps` (renamed from `foursailapps` on 2026-10-15 to match).

## Canonical record set (the whole zone; anything else is stale, delete it)

15 records. Email Routing owns the MX, SPF and DKIM rows; everything else is ours. If a record
is not in this table and not explained by a dated note below it, it should not exist.

| # | Type  | Name     | Content                                      | Owner | Purpose |
|---|-------|----------|----------------------------------------------|-------|---------|
| 1-4 | A   | `@`      | 185.199.108.153 / .109 / .110 / .111         | us    | GitHub Pages apex |
| 5-8 | AAAA| `@`      | 2606:50c0:8000::153 / 8001 / 8002 / 8003     | us    | GitHub Pages apex (IPv6) |
| 9 | CNAME | `www`    | foursailsapps.github.io                      | us    | www → Pages (GitHub 301s to apex) |
| 10-12 | MX | `@`     | route1 / route2 / route3.mx.cloudflare.net   | Email Routing | inbound mail |
| 13 | TXT  | `@`      | `v=spf1 include:_spf.mx.cloudflare.net ~all` | Email Routing | SPF (append `include:_spf.google.com` when Gmail send-as is set up) |
| 14 | TXT  | `_dmarc` | `v=DMARC1; p=none;`                          | us    | DMARC, monitor only |
| 15 | TXT  | `cf2024-1._domainkey` | `v=DKIM1; h=sha256; k=rsa; p=...` (2048-bit) | Email Routing | Cloudflare's DKIM key for mail it forwards/sends; key may rotate |

All DNS only (grey cloud). No other DKIM selector should exist: nothing else signs mail for this
domain until a sending provider is set up.

Not in the list but served anyway: Cloudflare answers `_acme-challenge` TXT queries with tokens
for its own Universal SSL certificate. They are invisible in the records tab and the export and
cannot be deleted there (see Cloudflare's "Unexpected _acme-challenge TXT records"). Harmless;
the audit reports them as `info`. Disabling Universal SSL (SSL/TLS > Edge Certificates) would
remove them, which is safe while nothing is proxied, but is not necessary.

Known stale records that have been removed and must not come back: Porkbun's `pixie.porkbun.com`
ALIAS/CNAME and parking A records; Porkbun MX (`fwd1/fwd2.porkbun.com`) and SPF
(`_spf.porkbun.com`); the MXToolbox DMARC (`p=quarantine; rua=...dmarc-report.com`); any
`www` CNAME to `andrewchae.github.io` or `foursailapps.github.io` (old org spellings);
two `_acme-challenge` TXT records and a 1024-bit `default._domainkey` DKIM TXT, all carried in by
Cloudflare's initial scan of the Porkbun zone (Porkbun's auto-SSL and forwarding leftovers;
GitHub Pages validates its certificate over HTTP, not DNS, so it never needs `_acme-challenge`).

Audit: `./dns-audit.sh` checks the live records with dig. To catch *extra* records, export the
zone (Cloudflare > DNS > Records > Import and Export > Export) and run
`./dns-audit.sh export.txt`; it diffs the export against this table.

## 1. Porkbun: nameservers only

Domain Management > foursailsapps.com > Authoritative Nameservers > replace the four Porkbun
nameservers with the two Cloudflare assigns to the zone. Leave everything else at Porkbun alone;
its DNS records and email forwards are ignored once the nameservers move.

## 2. Cloudflare: records

Add the zone (Add a domain > Connect a domain > `foursailsapps.com` > Free). Import
`foursailsapps.com.zone` (DNS > Records > Import and Export) with "Proxy imported DNS records"
unchecked, or add by hand. Every record is **DNS only** (grey cloud): proxying breaks GitHub's
certificate renewal and its HTTPS enforcement check.

| Type  | Name     | Content                 |
|-------|----------|-------------------------|
| A     | `@`      | 185.199.108.153         |
| A     | `@`      | 185.199.109.153         |
| A     | `@`      | 185.199.110.153         |
| A     | `@`      | 185.199.111.153         |
| AAAA  | `@`      | 2606:50c0:8000::153     |
| AAAA  | `@`      | 2606:50c0:8001::153     |
| AAAA  | `@`      | 2606:50c0:8002::153     |
| AAAA  | `@`      | 2606:50c0:8003::153     |
| CNAME | `www`    | foursailsapps.github.io     |
| TXT   | `_dmarc` | `v=DMARC1; p=none;`     |

Do not add MX or SPF by hand; Email Routing writes them (step 3). DMARC stays at `p=none`
while replies are sent through Gmail "Send mail as" (signed by gmail.com, not this domain).

## 3. Cloudflare: Email Routing

Email > Email Routing > Get started.

1. Destination address: the studio inbox; click the verification link it receives.
2. Catch-all → Send to that destination. (Explicit custom addresses are optional and take
   precedence over the catch-all; none are set as of 2026-10-15.)
3. "Add records and enable" writes the MX records (`route1/2/3.mx.cloudflare.net`) and the
   SPF TXT (`v=spf1 include:_spf.mx.cloudflare.net ~all`).

Replies: Gmail > Settings > Accounts > "Send mail as" > `support@foursailsapps.com` via
`smtp.gmail.com:587` with a Google App Password. Then append `include:_spf.google.com` to the
SPF record. Receive-only until that is done; replying from the personal address exposes it.

## 4. Verify

```
dig +short NS foursailsapps.com         # two *.ns.cloudflare.com
dig +short foursailsapps.com A          # four 185.199.x.153
dig +short foursailsapps.com AAAA       # four 2606:50c0:800x::153
dig +short www.foursailsapps.com CNAME  # foursailsapps.github.io.
dig +short MX foursailsapps.com         # route1/2/3.mx.cloudflare.net
curl -sI https://foursailsapps.com | head -1   # 200 from GitHub Pages
```

Send a test to `support@` from an account other than the destination inbox (a self-sent test
is merged into Gmail's Sent thread and never shows in the Inbox).

## 5. GitHub Pages HTTPS

Already enforced (2026-10-15). If the certificate ever needs re-issuing, confirm the records
above are DNS only, then:

```
gh api -X PUT repos/foursailsapps/foursails-site/pages -F https_enforced=true
```

## History

- 2026-10-15: registered at Porkbun; GitHub Pages records added at Porkbun; HTTPS enforced.
- 2026-10-15: Porkbun email forwarding tried (20-alias cap, no catch-all); replaced by
  Cloudflare Email Routing. Nameservers moved to Cloudflare. GitHub org renamed
  `foursailapps` → `foursailsapps`; `www` CNAME retargeted. Verified live the same day:
  NS phil/raquel.ns.cloudflare.com, MX route1-3.mx.cloudflare.net, SPF Cloudflare, DMARC
  p=none, catch-all enabled, site 200 over HTTPS, www 301 → apex.
