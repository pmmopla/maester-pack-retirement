function Test-RetirePhoneOnlyAdmin {
    <#
    .SYNOPSIS
    Finds admins whose only MFA methods are SMS or voice.
    #>
    [MaesterTest(
        Id                 = 'MP.RETIRE.1002',
        Title              = 'No admin relies only on SMS or voice for MFA',
        Product            = 'entra',
        Feature            = 'authentication-methods',
        Area               = 'privileged-access',
        ResourceType       = 'User',
        Severity           = 'High',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = ('T1111', 'T1078.004'),
        Service            = 'Graph',
        License            = 'AAD_PREMIUM',
        Permission         = 'Graph:Scope:AuditLog.Read.All',
        Tag                = ('Retirement', 'SMS')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The most admins to list in the result.
        [ValidateRange(1, 1000)]
        [int] $MaximumRows = 50
    )

    $details = @(Invoke-MtGraphRequest -RelativeUri 'reports/authenticationMethods/userRegistrationDetails')
    $admins = @($details | Where-Object { $_.isAdmin })
    $phoneOnly = @(Get-RetirePhoneOnlyUser -RegistrationDetail $details -AdminsOnly -IncludeGuests)

    if ($phoneOnly.Count -eq 0) {
        Add-MtTestResultDetail -Result "Well done. None of the $($admins.Count) admins relies only on SMS or voice for MFA."
        return $true
    }

    $result = "$($phoneOnly.Count) of $($admins.Count) admins rely only on SMS or voice for MFA. SMS and voice can be intercepted or redirected, and Microsoft-provided SMS and voice are retired on 1 February 2027.`n`n" +
        (Format-RetireUserTable -User $phoneOnly -MaximumRows $MaximumRows)
    Add-MtTestResultDetail -Result $result
    return $false
}
