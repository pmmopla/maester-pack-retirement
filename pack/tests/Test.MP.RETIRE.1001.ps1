function Test-RetirePhoneOnlyUser {
    <#
    .SYNOPSIS
    Finds users whose only MFA methods are SMS or voice, ahead of the retirement of Microsoft-provided SMS and voice.
    #>
    [MaesterTest(
        Id                 = 'MP.RETIRE.1001',
        Title              = 'No user relies only on SMS or voice for MFA',
        Product            = 'entra',
        Feature            = 'authentication-methods',
        Area               = 'authentication',
        ResourceType       = 'User',
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'Medium',
        Mitre              = 'T1111',
        Service            = 'Graph',
        License            = 'AAD_PREMIUM',
        Permission         = 'Graph:Scope:AuditLog.Read.All',
        Tag                = ('Retirement', 'SMS')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The most users to list in the result.
        [ValidateRange(1, 1000)]
        [int] $MaximumRows = 50,

        # Also check guest users.
        [bool] $IncludeGuests = $false
    )

    $details = @(Invoke-MtGraphRequest -RelativeUri 'reports/authenticationMethods/userRegistrationDetails')
    $phoneOnly = @(Get-RetirePhoneOnlyUser -RegistrationDetail $details -IncludeGuests:$IncludeGuests)
    $days = Get-RetireDaysUntil -Date '2027-02-01'

    if ($phoneOnly.Count -eq 0) {
        Add-MtTestResultDetail -Result "Well done. None of the $($details.Count) users checked relies only on SMS or voice for MFA."
        return $true
    }

    $when = if ($days -ge 0) { "in $days days (1 February 2027)" } else { 'since 1 February 2027' }
    $result = "$($phoneOnly.Count) of $($details.Count) users rely only on SMS or voice for MFA. Microsoft-provided SMS and voice are retired $when; after that these users must register a passkey before they can sign in.`n`n" +
        (Format-RetireUserTable -User $phoneOnly -MaximumRows $MaximumRows)
    Add-MtTestResultDetail -Result $result
    return $false
}
