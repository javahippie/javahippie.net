---
layout: post

title: "Fake sign-ups with "Automated protocol deliverability probe": what we did on mainz.social"

date: 2026-09-11 22:10:00 +0200

author: Tim Zöller

categories: mastodon security
---


Starting yesterday, September 10, Mastodon instances with open or approval-based registration have been receiving automated sign-ups with a recognisable pattern:

- Username: `bp` followed by 16 hex characters (e.g. `bp7d9702a4b613ab41`)
- Sign-up reason, always identical: "Automated protocol deliverability probe"
- Mostly Japanese email addresses (docomo.ne.jp, yahoo.co.jp, ybb.ne.jp), some gmail.com and icloud.com
- A different IP for every sign-up, roughly one every few minutes

## Why this is a problem

Mastodon sends the confirmation email right after sign-up, before you ever see the account in the approval queue. Approval protects your instance, but not your mail reputation.

In our case, *the emails did not bounce*. Our mail provider shows them as delivered. The addresses look like they belong to real people, who now get unsolicited mail from your domain. Every "report spam" click counts against you.

## Our solution

Anything that stops the sign-up before the account is saved also stops the email.

**Email domain blocks** (Admin → Moderation) for the Japanese carrier domains. Takes effect immediately, no restart. For most European instances the collateral damage is close to zero.

**A database CHECK constraint on the username pattern.** This is what we use. The insert fails, the whole sign-up transaction rolls back, and no email is sent. No restart required

```sql
ALTER TABLE accounts
  ADD CONSTRAINT reject_probe_username
  CHECK (domain IS NOT NULL OR username !~ '^bp[0-9a-f]{16}$')
  NOT VALID;
SQL
```

The `accounts` table also holds remote accounts from other instances. `domain IS NOT NULL` exempts them, so federation keeps working. Only local sign-ups are checked.

Reject any pending probe accounts first. `NOT VALID` skips existing rows when the constraint is added, but later updates to those rows would still fail.

The bot gets a 500 error, and you will see exceptions in your web logs. To remove the constraint later:

```sh
ALTER TABLE accounts DROP CONSTRAINT reject_probe_username;
```

This only works as long as the username pattern stays the same. IP blocks won't help much. The IPs are residential connections, many behind carrier-grade NAT.

## Please report it

According to [Spur](https://spur.us), all of the IPs we checked are callback proxy nodes carrying traffic from **Bright Data** (formerly Luminati) and **Oxylabs**. Both are commercial residential proxy providers with customer vetting and abuse reporting. They can map exit IP and timestamp to the paying customer.

Complaints to the ISPs behind the IPs are pointless. Complaints to the proxy providers are not. We have reported it to both. The more instances report, the harder it is to ignore.

Include the target instance, the timestamps in UTC, the exit IPs and the pattern described above.
