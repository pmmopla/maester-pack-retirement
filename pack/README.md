# M365 retirement readiness

Read-only Maester checks for the retirement of Microsoft-provided SMS and voice MFA in Microsoft Entra ID
(1 February 2027) and of Exchange Web Services in Exchange Online (1 April 2027).

```powershell
Install-MtPack pmmopla/maester-pack-retirement/pack
Invoke-Maester -Pack RETIRE -SkipBuiltIn
```

See the [repository README](https://github.com/pmmopla/maester-pack-retirement) for the checks, permissions
and settings.
