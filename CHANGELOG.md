# Changelog

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
