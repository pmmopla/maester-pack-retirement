Exchange Web Services (EWS) is being retired in Exchange Online. It is disabled by default from 1 October 2026
in tenants that have not chosen to keep it, and it is permanently shut down on 1 April 2027, with no
exceptions. Exchange Server on-premises is not affected.

This test lists the apps that hold an EWS permission in the tenant:

- the application permission `full_access_as_app` on **Office 365 Exchange Online**, and
- the delegated permission `EWS.AccessAsUser.All`, granted for all users or for one user.

Holding a permission does not prove that an app still calls EWS. Use the result as the list of apps to ask
about, and check the sign-in logs of each app before you remove anything.

#### Remediation action

1. For each app listed below, ask its owner or vendor whether it has moved to Microsoft Graph.
2. Apps that moved: remove the EWS permission in **Entra admin center** > **Enterprise apps** > the app >
   **Permissions**, or in its app registration.
3. Apps that have not moved: plan the move before 1 April 2027. Until then, an Exchange admin can keep EWS
   working for them by setting `EwsEnabled` to `True` and adding their application IDs to `EwsAllowedAppIDs`
   in `Set-OrganizationConfig` (MP.RETIRE.1004 checks this setting). The older `EwsAllowList` works on user
   agents and is not part of the retirement.

#### Related links

- [Exchange Online EWS, your time is almost up](https://techcommunity.microsoft.com/blog/Exchange/exchange-online-ews-your-time-is-almost-up/4492361)
- [Authenticate an EWS application by using OAuth](https://learn.microsoft.com/exchange/client-developer/exchange-web-services/how-to-authenticate-an-ews-application-by-using-oauth)

<!--- Results --->
%TestResult%
