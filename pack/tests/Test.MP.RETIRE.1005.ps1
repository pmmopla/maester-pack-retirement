function Test-RetirePasskeyPolicy {
    <#
    .SYNOPSIS
    Checks that users can register a passkey (FIDO2), the method that replaces Microsoft-provided SMS and voice.
    #>
    [MaesterTest(
        Id                 = 'MP.RETIRE.1005',
        Title              = 'Passkeys (FIDO2) are turned on for all users',
        Product            = 'entra',
        Feature            = 'authentication-methods',
        Area               = 'authentication',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'T1111',
        Service            = 'Graph',
        Permission         = 'Graph:Scope:Policy.Read.All',
        Tag                = ('Retirement', 'SMS', 'Passkey')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policy = Invoke-MtGraphRequest -RelativeUri 'policies/authenticationMethodsPolicy' | Select-Object -First 1
    $state = Get-RetirePasskeyPolicyState -Policy $policy
    $deadline = Get-RetireSmsDeadlineText
    $phone = if ($state.PhoneMethod.Count -gt 0) {
        " Still turned on in the policy: $($state.PhoneMethod -join ', '). Turn these off when no user relies on them (MP.RETIRE.1001 lists the users)."
    } else { '' }

    switch ($state.State) {
        'AllUsers' {
            Add-MtTestResultDetail -Result "Well done. Passkeys (FIDO2) are turned on for all users, so users who rely on SMS or voice can register one.$phone"
            return $true
        }
        'SomeUsers' {
            Add-MtTestResultDetail -Investigate -Result "Passkeys (FIDO2) are turned on for $($state.GroupCount) groups only, not for all users. Check that every user who relies on SMS or voice (MP.RETIRE.1001 lists them) is in one of these groups; a user outside them cannot register a passkey. $deadline$phone"
            return $false
        }
        default {
            Add-MtTestResultDetail -Result "Passkeys (FIDO2) are turned off in the Authentication methods policy. $deadline After that, a user whose only MFA method is SMS or voice must register a passkey before they can sign in.$phone"
            return $false
        }
    }
}
