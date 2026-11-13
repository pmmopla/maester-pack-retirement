When Microsoft retires its SMS and voice delivery for multifactor authentication (1 February 2027 for most
users, 1 July 2027 for Global Administrators and external users), a user whose only MFA method is a phone
number must register a passkey before they can sign in. That only works when the tenant lets them register one.

This test reads the **Passkey (FIDO2)** method in the Authentication methods policy:

- **Passed**: the method is turned on for all users.
- **Investigate**: the method is turned on for some groups only. Compare the groups with the users that
  MP.RETIRE.1001 lists.
- **Failed**: the method is turned off.

The result also says whether SMS or voice is still turned on in the policy. The test reads the policy as you
configured it. Since 1 September 2026 Microsoft also turns passkeys on for users enabled for SMS or voice,
unless the tenant opted out; that automatic change is not read here.

#### Remediation action

1. In **Entra admin center** > **Entra ID** > **Authentication methods** > **Policies**, open
   **Passkey (FIDO2)**.
2. Turn it on and set the target to **All users**, or to groups that cover every user who relies on SMS or
   voice.
3. Ask those users to register a passkey at [My Security Info](https://mysignins.microsoft.com/security-info).
4. When MP.RETIRE.1001 passes, turn off **SMS** and **Voice call** in the same policy.

#### Related links

- [Microsoft-provided SMS and voice retirement](https://learn.microsoft.com/entra/identity/authentication/concept-sms-voice-retirement)
- [Enable passkeys (FIDO2) for your organization](https://learn.microsoft.com/entra/identity/authentication/how-to-enable-passkey-fido2)
- [authenticationMethodsPolicy resource type](https://learn.microsoft.com/graph/api/resources/authenticationmethodspolicy)

<!--- Results --->
%TestResult%
