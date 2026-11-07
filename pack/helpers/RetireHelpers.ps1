function Get-RetirePhoneMethodName {
    <#
    .SYNOPSIS
    The methodsRegistered values that are delivered by phone call or text message.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    @('mobilePhone', 'alternateMobilePhone', 'officePhone')
}

function Get-RetireNonMfaMethodName {
    <#
    .SYNOPSIS
    The methodsRegistered values that can reset a password but cannot satisfy MFA.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    @('email', 'securityQuestion')
}

function Get-RetirePhoneOnlyUser {
    <#
    .SYNOPSIS
    Returns the users whose only registered MFA methods are phone methods (SMS or voice).

    .DESCRIPTION
    Takes userRegistrationDetails objects from Microsoft Graph and keeps the users that have at least one phone
    method and no other MFA method. Email and security questions are ignored, because they cannot satisfy MFA.
    Users with no MFA method at all are not returned: they are a different problem.

    .PARAMETER RegistrationDetail
    Objects from GET /reports/authenticationMethods/userRegistrationDetails.

    .PARAMETER IncludeGuests
    Also return guest users. Off by default, because guests usually register MFA in their home tenant.

    .PARAMETER AdminsOnly
    Return only users that Microsoft Graph reports as admins (isAdmin).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $RegistrationDetail,

        [switch] $IncludeGuests,

        [switch] $AdminsOnly
    )

    $phone = Get-RetirePhoneMethodName
    $ignored = Get-RetireNonMfaMethodName

    foreach ($user in $RegistrationDetail) {
        if ($null -eq $user) { continue }
        if (-not $IncludeGuests -and $user.userType -eq 'guest') { continue }
        if ($AdminsOnly -and -not [bool]$user.isAdmin) { continue }

        $methods = @($user.methodsRegistered | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $phoneMethods = @($methods | Where-Object { $_ -in $phone })
        $otherMfa = @($methods | Where-Object { $_ -notin $phone -and $_ -notin $ignored })

        if ($phoneMethods.Count -gt 0 -and $otherMfa.Count -eq 0) {
            [pscustomobject]@{
                id                = $user.id
                userPrincipalName = $user.userPrincipalName
                displayName       = $user.userDisplayName
                isAdmin           = [bool]$user.isAdmin
                methods           = ($methods -join ', ')
            }
        }
    }
}

function Get-RetireEwsPermissionId {
    <#
    .SYNOPSIS
    The IDs of the Exchange Web Services permissions on the Office 365 Exchange Online API.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    @{
        # Office 365 Exchange Online
        ExchangeAppId          = '00000002-0000-0ff1-ce00-000000000000'
        # Application permission full_access_as_app (EWS, app-only)
        FullAccessAsAppRoleId  = 'dc890d15-9560-4a4c-9b7f-a736ec74ec40'
        # Delegated permission EWS.AccessAsUser.All
        AccessAsUserScopeValue = 'EWS.AccessAsUser.All'
    }
}

function Get-RetireEwsGrant {
    <#
    .SYNOPSIS
    Returns the apps that hold an Exchange Web Services permission in the tenant.

    .DESCRIPTION
    Combines the app role assignments of the Exchange Online service principal (application permission
    full_access_as_app) with the delegated permission grants whose scope includes EWS.AccessAsUser.All.
    Each app appears once, with every EWS permission it holds.

    .PARAMETER AppRoleAssignment
    Objects from GET /servicePrincipals/{exchange-sp-id}/appRoleAssignedTo.

    .PARAMETER DelegatedGrant
    Objects from GET /oauth2PermissionGrants.

    .PARAMETER ServicePrincipal
    Service principals of the client apps, used to show their names and app IDs. Optional.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowEmptyCollection()]
        [object[]] $AppRoleAssignment = @(),

        [AllowEmptyCollection()]
        [object[]] $DelegatedGrant = @(),

        [AllowEmptyCollection()]
        [object[]] $ServicePrincipal = @()
    )

    $ids = Get-RetireEwsPermissionId
    $byClient = [ordered]@{}

    $names = @{}
    foreach ($sp in $ServicePrincipal) {
        if ($sp -and $sp.id) { $names[[string]$sp.id] = $sp }
    }

    foreach ($assignment in $AppRoleAssignment) {
        if ($null -eq $assignment) { continue }
        if ([string]$assignment.appRoleId -ne $ids.FullAccessAsAppRoleId) { continue }
        $clientId = [string]$assignment.principalId
        if (-not $byClient.Contains($clientId)) {
            $byClient[$clientId] = [System.Collections.Generic.List[string]]::new()
        }
        $byClient[$clientId].Add('full_access_as_app (application)')
    }

    foreach ($grant in $DelegatedGrant) {
        if ($null -eq $grant) { continue }
        $scopes = @(([string]$grant.scope) -split '\s+' | Where-Object { $_ })
        if ($ids.AccessAsUserScopeValue -notin $scopes) { continue }
        $clientId = [string]$grant.clientId
        if (-not $byClient.Contains($clientId)) {
            $byClient[$clientId] = [System.Collections.Generic.List[string]]::new()
        }
        $who = if ($grant.consentType -eq 'AllPrincipals') { 'all users' } else { 'one user' }
        $label = "EWS.AccessAsUser.All (delegated, $who)"
        if ($label -notin $byClient[$clientId]) { $byClient[$clientId].Add($label) }
    }

    foreach ($clientId in $byClient.Keys) {
        $sp = $names[$clientId]
        $principalName = ($AppRoleAssignment | Where-Object { [string]$_.principalId -eq $clientId } |
            Select-Object -First 1).principalDisplayName
        [pscustomobject]@{
            id          = $clientId
            displayName = if ($sp.displayName) { $sp.displayName } elseif ($principalName) { $principalName } else { $clientId }
            appId       = $sp.appId
            permissions = ($byClient[$clientId] -join '; ')
        }
    }
}

function ConvertTo-RetireMarkdownCell {
    <#
    .SYNOPSIS
    Makes a value safe to put in a Markdown table cell.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object] $Value
    )

    if ($null -eq $Value) { return '' }
    ([string]$Value) -replace '\\', '\\' -replace '\|', '\|' -replace '[\r\n]+', ' ' -replace '<', '&lt;' -replace '>', '&gt;'
}

function Format-RetireUserTable {
    <#
    .SYNOPSIS
    A Markdown table of users, cut to a maximum number of rows.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $User,

        [int] $MaximumRows = 50
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('| User | Admin | Registered methods |')
    $lines.Add('| --- | --- | --- |')
    foreach ($u in ($User | Select-Object -First $MaximumRows)) {
        $admin = if ($u.isAdmin) { 'Yes' } else { 'No' }
        $lines.Add("| $(ConvertTo-RetireMarkdownCell $u.userPrincipalName) | $admin | $(ConvertTo-RetireMarkdownCell $u.methods) |")
    }
    if ($User.Count -gt $MaximumRows) {
        $lines.Add('')
        $lines.Add("Showing $MaximumRows of $($User.Count) users. Raise ``MaximumRows`` in maester-config.json to see more.")
    }
    $lines -join "`n"
}

function Format-RetireAppTable {
    <#
    .SYNOPSIS
    A Markdown table of apps that hold EWS permissions.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $App
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('| App | App ID | EWS permissions |')
    $lines.Add('| --- | --- | --- |')
    foreach ($a in $App) {
        $lines.Add("| $(ConvertTo-RetireMarkdownCell $a.displayName) | $(ConvertTo-RetireMarkdownCell $a.appId) | $(ConvertTo-RetireMarkdownCell $a.permissions) |")
    }
    $lines -join "`n"
}

function Get-RetireDaysUntil {
    <#
    .SYNOPSIS
    Whole days from Now until Date; negative when the date has passed.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [datetime] $Date,

        [datetime] $Now = [datetime]::UtcNow
    )

    [int][math]::Floor(($Date.Date - $Now.Date).TotalDays)
}
