Exchange Web Services (EWS) is being retired in Exchange Online. Since October 2026 the tenant setting
`EwsEnabled` decides which apps can still use it, and on 1 April 2027 EWS is permanently shut down, with no
exceptions. Exchange Server on-premises is not affected.

| `EwsEnabled` | What it means since October 2026 | This test |
| --- | --- | --- |
| `False` | EWS is blocked for the whole tenant. | Passes |
| `True`, `EwsAllowedAppIDs` empty | No app is allowed to use EWS. | Passes |
| `True`, `EwsAllowedAppIDs` lists apps | Only those apps can use EWS, until 1 April 2027. | Fails and lists the apps |
| Not set (`null`) | Every app can use EWS. Microsoft changes this to `False` as its rollout reaches the tenant; setting it back to `null` is the temporary workaround. | Fails |

The allow list that matters for the retirement is `EwsAllowedAppIDs` (application IDs). The older
`EwsAllowList` and `EwsBlockList` (user agents, used with `EwsApplicationAccessPolicy`) are not part of the
retirement, so this test does not read them.

This test reads the settings only. It needs the **View-Only Configuration** role in Exchange Online, and an
Exchange Online PowerShell module recent enough to run `Get-OrganizationConfig -RetrieveEwsOperationAccessPolicy`.
With an older module the result is **Investigate**.

#### Remediation action

1. Run MP.RETIRE.1003 to see which apps hold EWS permissions, and check the
   [EWS usage report](https://learn.microsoft.com/microsoft-365/admin/activity-reports/ews-usage) to see which
   ones still call EWS.
2. Ask the owner or vendor of each app to move it to Microsoft Graph before 1 April 2027.
3. Until then, keep EWS only for the apps that still need it, in Exchange Online PowerShell:

   ```powershell
   Set-OrganizationConfig -EwsEnabled $true -EwsAllowedAppIDs "<app ID 1>,<app ID 2>"
   ```

   When no app needs EWS any more, block it with `Set-OrganizationConfig -EwsEnabled $false`.
   Changes to `EwsAllowedAppIDs` can take up to 24 hours to apply.

#### Related links

- [Exchange Online EWS, your time is almost up](https://techcommunity.microsoft.com/blog/Exchange/exchange-online-ews-your-time-is-almost-up/4492361)
- [Control access to EWS in Exchange](https://learn.microsoft.com/exchange/client-developer/exchange-web-services/how-to-control-access-to-ews-in-exchange)
- [Set-OrganizationConfig](https://learn.microsoft.com/powershell/module/exchangepowershell/set-organizationconfig)

<!--- Results --->
%TestResult%
