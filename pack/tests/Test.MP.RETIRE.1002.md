Admins should use a phishing-resistant method such as a passkey, Windows Hello for Business or a FIDO2
security key. SMS and voice are among the weakest MFA methods, and Microsoft-provided SMS and voice are retired
in Microsoft Entra ID on 1 February 2027 (1 July 2027 for Global Administrators and external users).

This test lists the users that Microsoft Graph reports as admins (`isAdmin`) whose only registered MFA
methods are phone methods. Guest admins are included.

#### Remediation action

1. Register a passkey or FIDO2 security key for each admin listed below, then remove their phone methods.
2. Require phishing-resistant MFA for admin roles with a Conditional Access authentication strength.
3. Keep two emergency access accounts with FIDO2 keys, excluded from the policy and monitored.

#### Related links

- [Microsoft-provided SMS and voice retirement](https://learn.microsoft.com/entra/identity/authentication/concept-sms-voice-retirement)
- [Require phishing-resistant MFA for admins](https://learn.microsoft.com/entra/identity/conditional-access/policy-admin-phish-resistant-mfa)

<!--- Results --->
%TestResult%
