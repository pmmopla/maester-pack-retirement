function Test-RetireEwsTenantSetting {
    <#
    .SYNOPSIS
    Checks whether the tenant still lets apps use Exchange Web Services (EWS) ahead of the shutdown on 1 April 2027.
    #>
    [MaesterTest(
        Id                 = 'MP.RETIRE.1004',
        Title              = 'No app is still allowed to use Exchange Web Services',
        Product            = 'exchange',
        Feature            = 'client-access',
        Area               = 'applications',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'Medium',
        Mitre              = 'T1114.002',
        Service            = 'ExchangeOnline',
        Permission         = ('ExchangeOnline:Role:View-Only Configuration', 'ExchangeOnline:Cmdlet:Get-OrganizationConfig'),
        Tag                = ('Retirement', 'EWS')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $config = Get-MtExo -Request OrganizationConfig | Select-Object -First 1
    $allowed = @()
    $listUnknown = $false
    if ($config.EwsEnabled -eq $true) {
        $command = Get-Command -Name Get-OrganizationConfig -ErrorAction SilentlyContinue
        if ($command -and $command.Parameters.ContainsKey('RetrieveEwsOperationAccessPolicy')) {
            $policy = Get-OrganizationConfig -RetrieveEwsOperationAccessPolicy | Select-Object -First 1
            $allowed = @(ConvertTo-RetireAppIdList -Value $policy.EwsAllowedAppIDs)
        } else {
            $listUnknown = $true
        }
    }

    $state = Get-RetireEwsTenantState -EwsEnabled $config.EwsEnabled -AllowedAppId $allowed -AllowListUnknown:$listUnknown
    $days = Get-RetireDaysUntil -Date '2027-04-01'
    $when = if ($days -ge 0) { "EWS is shut down in Exchange Online in $days days (1 April 2027)." } else { 'EWS was shut down in Exchange Online on 1 April 2027.' }

    switch ($state.State) {
        'Blocked' {
            Add-MtTestResultDetail -Result "Well done. No app can use Exchange Web Services in this tenant ($($state.Reason))."
            return $true
        }
        'AllowList' {
            $result = "$($state.AllowedAppId.Count) apps are still allowed to use Exchange Web Services ($($state.Reason)). $when Each of these apps stops working with EWS then, so move it to Microsoft Graph or replace it. Look up each ID in **Entra admin center** > **Enterprise apps**.`n`n" +
                (Format-RetireAppIdTable -AppId $state.AllowedAppId)
            Add-MtTestResultDetail -Result $result
            return $false
        }
        'AllowListUnknown' {
            Add-MtTestResultDetail -Investigate -Result "Exchange Web Services is turned on (EwsEnabled is True), but this version of the Exchange Online module cannot read the allowed app list. Update ExchangeOnlineManagement, or run ``Get-OrganizationConfig -RetrieveEwsOperationAccessPolicy | Format-List EwsAllowedAppIDs`` and check the list yourself. $when"
            return $false
        }
        default {
            Add-MtTestResultDetail -Result "Every app can still use Exchange Web Services in this tenant ($($state.Reason)). Microsoft changes an unset EwsEnabled to False as its rollout reaches each tenant, and setting it back to null is the temporary workaround that turns EWS on without any restriction. $when Set EwsEnabled to False, or to True with only the apps you still need in EwsAllowedAppIDs."
            return $false
        }
    }
}
