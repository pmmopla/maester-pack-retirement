Microsoft is retiring Microsoft-provided SMS and voice for multifactor authentication in Microsoft Entra ID.
Passkeys became the default on 1 September 2026. SMS and voice are retired on 1 February 2027 for all users
except Global Administrators and external users, and on 1 July 2027 for Global Administrators and external
users. After their date, a user whose only MFA method is a phone number gets a blocking prompt to register a
passkey before they can sign in. There is no opt-out from either date.

This test lists the users whose only registered MFA methods are phone methods (`mobilePhone`,
`alternateMobilePhone`, `officePhone`). Email and security questions are ignored, because they cannot satisfy
MFA. Guests are left out unless you set `IncludeGuests`; the **Type** column tells members and guests apart.

```json
{
  "TestSettings": [
    { "Id": "MP.RETIRE.1001", "Parameters": { "MaximumRows": 200, "IncludeGuests": true } }
  ]
}
```

#### Remediation action

1. Enable passkeys (FIDO2) and Microsoft Authenticator in **Entra admin center** > **Entra ID** >
   **Authentication methods** > **Policies**.
2. Ask each user listed below to register a passkey or Microsoft Authenticator at
   [My Security Info](https://mysignins.microsoft.com/security-info), or run a registration campaign.
3. When every user has a stronger method, remove SMS and voice from the users' allowed methods.

#### Related links

- [Microsoft-provided SMS and voice retirement](https://learn.microsoft.com/entra/identity/authentication/concept-sms-voice-retirement)
- [Authentication methods policy](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods)

<!--- Results --->
%TestResult%
