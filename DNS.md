# DNS for foursailsapps.com (Porkbun -> GitHub Pages)

The site is served by GitHub Pages from the `andrewchae/foursails-site` repo. The repo already
contains `CNAME` (`foursailsapps.com`) and the Pages custom domain is set via the API. Nothing
below is done automatically; add these records in Porkbun > Domain Management > foursailsapps.com > DNS.

## 1. Delete Porkbun's defaults first

Porkbun pre-creates records that will conflict. Delete, for the apex and `www`:

- any `ALIAS` or `CNAME` record on the apex (`foursailsapps.com`) pointing at `pixie.porkbun.com`
- any `A` record on the apex pointing at Porkbun parking IPs
- any `CNAME` on `www` pointing at `pixie.porkbun.com`
- any URL forwarding entry for the domain (Domain Management > URL Forwarding)

Do NOT delete the `MX` records or the `TXT`/SPF record Porkbun created for email forwarding.

## 2. Add these records

| Type  | Host  | Answer                     | TTL |
|-------|-------|----------------------------|-----|
| A     | (blank / apex) | 185.199.108.153   | 600 |
| A     | (blank / apex) | 185.199.109.153   | 600 |
| A     | (blank / apex) | 185.199.110.153   | 600 |
| A     | (blank / apex) | 185.199.111.153   | 600 |
| AAAA  | (blank / apex) | 2606:50c0:8000::153 | 600 |
| AAAA  | (blank / apex) | 2606:50c0:8001::153 | 600 |
| AAAA  | (blank / apex) | 2606:50c0:8002::153 | 600 |
| AAAA  | (blank / apex) | 2606:50c0:8003::153 | 600 |
| CNAME | www   | andrewchae.github.io       | 600 |

In Porkbun the "Host" field for the apex is left empty (Porkbun appends the domain).

Do not add any MX records: Porkbun's email forwarding depends on the MX records it already manages.

## 3. Verify

After a few minutes:

```
dig +short foursailsapps.com A        # four 185.199.x.153 addresses
dig +short foursailsapps.com AAAA     # four 2606:50c0:800x::153 addresses
dig +short www.foursailsapps.com CNAME  # andrewchae.github.io.
curl -sI http://foursailsapps.com | head -3   # 301/200 from GitHub Pages
```

## 4. Enforce HTTPS (after DNS resolves)

GitHub issues a Let's Encrypt certificate once it can see the DNS above (usually under an hour,
up to 24 h). Then:

1. Open https://github.com/andrewchae/foursails-site/settings/pages
2. Confirm "Custom domain" shows `foursailsapps.com` with a green "DNS check successful".
3. Tick **Enforce HTTPS**. (It is greyed out until the certificate is issued; retry later.)

Or from the CLI once the cert exists:

```
gh api -X PUT repos/andrewchae/foursails-site/pages -F https_enforced=true
```

## 5. Email forwarding (support@ and per-app aliases)

Email forwarding is configured in Porkbun, not in DNS records you add by hand:
Porkbun > Domain Management > foursailsapps.com > Email Forwarding.

- Add `support` -> your inbox.
- Add `fuel-log` and `pool-calc` -> your inbox (the site links to `<app>@foursailsapps.com`).
- Add a catch-all (`*`) -> your inbox so future `<app>@` aliases work without extra setup.

Porkbun writes the MX records it needs when forwarding is enabled; leave those records as they are.
