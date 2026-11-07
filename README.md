# M365 retirement readiness — a Maester Pack

Read-only checks that find what will break when Microsoft retires two things that many small and medium
businesses still depend on:

| Date | What Microsoft retires | Checked by |
| --- | --- | --- |
| 1 February 2027 | Microsoft-provided SMS and voice MFA in Microsoft Entra ID | MP.RETIRE.1001, MP.RETIRE.1002 |
| 1 April 2027 | Exchange Web Services (EWS) in Exchange Online (off by default since 1 October 2026) | MP.RETIRE.1003, MP.RETIRE.1004 |

> **Status: preview (0.2.0).** The checks are unit-tested against sample Microsoft Graph responses, but they
> have not yet been run against many real tenants. If you run them, please
> [open an issue](https://github.com/pmmopla/maester-pack-retirement/issues) with what you saw (no tenant data,
> please) — that is the most useful contribution right now.

## Try it

You need [Maester](https://maester.dev) 3.0 or later (packs are in the 3.0 preview).

```powershell
Install-Module Maester -AllowPrerelease -Scope CurrentUser
Install-MtPack pmmopla/maester-pack-retirement/pack
Connect-Maester -Service Graph, ExchangeOnline
Invoke-Maester -Pack RETIRE -SkipBuiltIn
```

Without an Exchange Online connection, MP.RETIRE.1004 is skipped and the other checks still run.

The pack changes nothing in your tenant. It reads Microsoft Graph and Exchange Online with these permissions:

| Permission | Used by |
| --- | --- |
| `AuditLog.Read.All` | MP.RETIRE.1001, MP.RETIRE.1002 (user registration details) |
| `Application.Read.All` | MP.RETIRE.1003 (service principals and app role assignments) |
| `DelegatedPermissionGrant.Read.All` | MP.RETIRE.1003 (delegated permission grants) |
| Exchange Online **View-Only Configuration** role | MP.RETIRE.1004 (`Get-OrganizationConfig`) |

MP.RETIRE.1001 and 1002 are declared as needing Microsoft Entra ID P1 or better (included in Microsoft 365
Business Premium), because the registration report is part of Entra's premium reporting; Maester skips them in
tenants without it.

## The checks

| ID | Check | Severity |
| --- | --- | --- |
| MP.RETIRE.1001 | No user relies only on SMS or voice for MFA | Medium |
| MP.RETIRE.1002 | No admin relies only on SMS or voice for MFA | High |
| MP.RETIRE.1003 | No app still holds Exchange Web Services permissions | Medium |
| MP.RETIRE.1004 | No app is still allowed to use Exchange Web Services (tenant setting) | Medium |

Settings you can change in `maester-config.json`:

```json
{
  "TestSettings": [
    { "Id": "MP.RETIRE.1001", "Parameters": { "MaximumRows": 200, "IncludeGuests": true } },
    { "Id": "MP.RETIRE.1002", "Parameters": { "MaximumRows": 200 } }
  ]
}
```

### How "relies only on SMS or voice" is decided

A user is listed when their `methodsRegistered` contains at least one phone method (`mobilePhone`,
`alternateMobilePhone`, `officePhone`) and no other MFA method. Email and security questions are ignored
because they cannot satisfy MFA. Users with no MFA method at all are not listed: that is a different problem.

### What MP.RETIRE.1003 can and cannot tell you

It lists apps that hold `full_access_as_app` on Office 365 Exchange Online or a delegated grant of
`EWS.AccessAsUser.All`. Holding a permission does not prove an app still calls EWS, so treat the list as the
apps to ask about, not the apps to delete.

### What MP.RETIRE.1004 checks

The tenant setting that decides which apps can still use EWS until 1 April 2027: `EwsEnabled` and the
application ID allow list `EwsAllowedAppIDs`. It passes when EWS is blocked (`EwsEnabled` is `False`, or
`True` with an empty list), fails and lists the apps when the list has entries, and fails when `EwsEnabled`
is not set, because then every app can use EWS. The older `EwsAllowList` (user agents) is not part of the
retirement and is not read. With an Exchange Online module too old to read the allow list, the result is
**Investigate**.

## Roadmap

- SMTP AUTH: mailboxes and apps still using Basic authentication for client submission (needs an Exchange
  Online connection).
- Users enabled for SMS or voice in the authentication methods policy who have not registered a passkey yet.

## Develop

The pack is in [`pack/`](pack). The unit tests in [`unit-tests/`](unit-tests) replace Microsoft Graph with
JSON files, so they need no tenant:

```powershell
Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser
Invoke-Pester ./unit-tests

Install-Module Maester -AllowPrerelease -Scope CurrentUser
Test-MtPack ./pack
Invoke-MtTest -Path ./pack
```

Every push and pull request runs the same checks in GitHub Actions.

## Licence

[MIT](LICENSE). Not affiliated with Microsoft or the Maester project.
