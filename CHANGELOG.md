# Changelog

## 0.3.0

- Fixed: Microsoft retires SMS and voice in two waves, 1 February 2027 for most users and 1 July 2027 for
  Global Administrators and external users. The results and descriptions of MP.RETIRE.1001 and 1002 said
  1 February 2027 for everyone.
- MP.RETIRE.1005: the Passkey (FIDO2) method is turned on for all users. Needs `Policy.Read.All`.
- MP.RETIRE.1001 and 1002: the user table has a **Type** column (member or guest).
- The pack has a guide (`maester-pack.guide.json`) with the connect and run commands.
- The README installs Maester with `Install-PSResource -Name Maester -Prerelease`.

## 0.2.0

- MP.RETIRE.1004: the tenant EWS setting (`EwsEnabled` and the `EwsAllowedAppIDs` allow list). Needs an
  Exchange Online connection; skipped without one.
- MP.RETIRE.1003: the remediation now points to `EwsAllowedAppIDs`, the allow list used for the EWS
  retirement, instead of the older user-agent `EwsAllowList`.

## 0.1.0

- First preview release.
- MP.RETIRE.1001: users whose only MFA methods are SMS or voice.
- MP.RETIRE.1002: admins whose only MFA methods are SMS or voice.
- MP.RETIRE.1003: apps that hold Exchange Web Services permissions.
