function Test-RetireEwsPermission {
    <#
    .SYNOPSIS
    Finds apps that still hold Exchange Web Services (EWS) permissions ahead of the EWS shutdown in Exchange Online.
    #>
    [MaesterTest(
        Id                 = 'MP.RETIRE.1003',
        Title              = 'No app still holds Exchange Web Services permissions',
        Product            = 'entra',
        RelatedProduct     = 'exchange',
        Feature            = 'app-permissions',
        Area               = 'applications',
        ResourceType       = 'ServicePrincipal',
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'High',
        Mitre              = 'T1114.002',
        Service            = 'Graph',
        Permission         = ('Graph:Scope:Application.Read.All', 'Graph:Scope:DelegatedPermissionGrant.Read.All | Graph:Scope:Directory.Read.All'),
        Tag                = ('Retirement', 'EWS')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $ids = Get-RetireEwsPermissionId
    $exchange = Invoke-MtGraphRequest -RelativeUri 'servicePrincipals' -Filter "appId eq '$($ids.ExchangeAppId)'" | Select-Object -First 1
    if (-not $exchange) {
        Add-MtTestResultDetail -SkippedBecause NotApplicable
        return $null
    }

    $assignments = @(Invoke-MtGraphRequest -RelativeUri "servicePrincipals/$($exchange.id)/appRoleAssignedTo")
    $grants = @(Invoke-MtGraphRequest -RelativeUri 'oauth2PermissionGrants')
    $clientIds = @(@($assignments.principalId) + @($grants.clientId) | Where-Object { $_ } | Select-Object -Unique)
    $clients = if ($clientIds.Count -gt 0) {
        @(Invoke-MtGraphRequest -RelativeUri 'servicePrincipals' -UniqueId $clientIds -Select 'id', 'displayName', 'appId')
    } else { @() }

    $apps = @(Get-RetireEwsGrant -AppRoleAssignment $assignments -DelegatedGrant $grants -ServicePrincipal $clients)
    $days = Get-RetireDaysUntil -Date '2027-04-01'

    if ($apps.Count -eq 0) {
        Add-MtTestResultDetail -Result 'Well done. No app holds an Exchange Web Services permission.'
        return $true
    }

    $when = if ($days -ge 0) { "is shut down in Exchange Online in $days days (1 April 2027)" } else { 'was shut down in Exchange Online on 1 April 2027' }
    $result = "$($apps.Count) apps still hold Exchange Web Services permissions. EWS $when, and is off by default since 1 October 2026 unless the tenant allows it. Move each app to Microsoft Graph, or remove the permission if the app no longer uses EWS.`n`n" +
        (Format-RetireAppTable -App $apps)
    Add-MtTestResultDetail -Result $result
    return $false
}
