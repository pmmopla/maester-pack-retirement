# Unit tests for the pack. They need no tenant and no Maester connection: Microsoft Graph is replaced by the
# JSON files in ./fixtures. Run with: Invoke-Pester ./unit-tests
BeforeAll {
    $root = Join-Path (Split-Path -Parent $PSScriptRoot) 'pack'

    # The engine reads [MaesterTest(...)] from the syntax tree. Outside the engine the type does not exist, so
    # give PowerShell a stand-in attribute that accepts the same named arguments.
    if (-not ('MaesterTest' -as [type])) {
        Add-Type -TypeDefinition @'
public class MaesterTest : System.Attribute {
    public object Id; public object Title; public object Product; public object RelatedProduct; public object Feature;
    public object Area; public object ResourceType; public object Severity; public object UserImpact;
    public object ImplementationCost; public object Mitre; public object Service; public object License;
    public object Permission; public object Tag; public object HelpUrl; public object InstanceSource;
}
'@
    }

    function Read-Fixture([string] $Name) {
        Get-Content -LiteralPath (Join-Path $PSScriptRoot "fixtures/$Name.json") -Raw | ConvertFrom-Json
    }

    # Stand-ins for the Maester commands the tests call.
    $script:Graph = @{}
    function global:Invoke-MtGraphRequest {
        param([string[]] $RelativeUri, [string[]] $UniqueId, [string[]] $Select, [string] $Filter)
        $key = $RelativeUri[0]
        if ($UniqueId) { return @($script:Graph['clients'] | Where-Object { $_.id -in $UniqueId }) }
        if ($Filter -and $key -eq 'servicePrincipals') { return $script:Graph['exchange'] }
        if ($key -like 'servicePrincipals/*/appRoleAssignedTo') { return $script:Graph['assignments'] }
        return $script:Graph[$key]
    }
    function global:Add-MtTestResultDetail {
        param([string] $Result, [string] $SkippedBecause, [switch] $Investigate)
        $script:LastResult = $Result
        $script:LastSkip = $SkippedBecause
        $script:LastInvestigate = [bool]$Investigate
    }

    # Exchange Online stand-ins. $script:Exo.OrganizationConfig is what Get-MtExo returns, and
    # $script:Exo.EwsPolicy what Get-OrganizationConfig -RetrieveEwsOperationAccessPolicy returns. Without
    # $script:Exo.ModuleCanReadAllowList the stand-in has no such parameter, like an old Exchange module.
    $script:Exo = @{}
    function global:Get-MtExo {
        param([string] $Request)
        $script:Exo[$Request]
    }
    function Set-ExoFixture([string] $Name, [switch] $OldModule) {
        $fixture = (Read-Fixture organizationConfig).$Name
        $script:Exo = @{
            OrganizationConfig = [pscustomobject]@{ EwsEnabled = $fixture.EwsEnabled }
            EwsPolicy          = [pscustomobject]@{ EwsAllowedAppIDs = $fixture.EwsAllowedAppIDs }
        }
        if ($OldModule) {
            function global:Get-OrganizationConfig { $script:Exo['OrganizationConfig'] }
        } else {
            function global:Get-OrganizationConfig {
                param([switch] $RetrieveEwsOperationAccessPolicy)
                if ($RetrieveEwsOperationAccessPolicy) { return $script:Exo['EwsPolicy'] }
                $script:Exo['OrganizationConfig']
            }
        }
    }

    . (Join-Path $root 'helpers/RetireHelpers.ps1')
    Get-ChildItem (Join-Path $root 'tests') -Filter 'Test.*.ps1' | ForEach-Object { . $_.FullName }
}

AfterAll {
    Remove-Item function:global:Invoke-MtGraphRequest, function:global:Add-MtTestResultDetail,
        function:global:Get-MtExo, function:global:Get-OrganizationConfig -ErrorAction SilentlyContinue
}

Describe 'Get-RetirePhoneOnlyUser' {
    BeforeAll { $details = @(Read-Fixture userRegistrationDetails) }

    It 'returns members whose only MFA methods are phone methods' {
        $ids = @(Get-RetirePhoneOnlyUser -RegistrationDetail $details).id
        $ids | Should -Be @('u1', 'u3', 'u7')
    }
    It 'ignores email and security questions when deciding' {
        (Get-RetirePhoneOnlyUser -RegistrationDetail $details | Where-Object id -eq 'u3').methods | Should -Be 'mobilePhone, email'
    }
    It 'leaves out users with a stronger method, no method, or no phone method' {
        $ids = @(Get-RetirePhoneOnlyUser -RegistrationDetail $details).id
        $ids | Should -Not -Contain 'u2'
        $ids | Should -Not -Contain 'u6'
        $ids | Should -Not -Contain 'u8'
    }
    It 'leaves out guests unless asked' {
        @(Get-RetirePhoneOnlyUser -RegistrationDetail $details).id | Should -Not -Contain 'u5'
        @(Get-RetirePhoneOnlyUser -RegistrationDetail $details -IncludeGuests).id | Should -Contain 'u5'
    }
    It 'returns only admins with -AdminsOnly' {
        @(Get-RetirePhoneOnlyUser -RegistrationDetail $details -AdminsOnly).id | Should -Be @('u3')
    }
    It 'accepts an empty list' {
        @(Get-RetirePhoneOnlyUser -RegistrationDetail @()).Count | Should -Be 0
    }
}

Describe 'Get-RetireEwsGrant' {
    BeforeAll {
        $apps = @(Get-RetireEwsGrant -AppRoleAssignment (Read-Fixture appRoleAssignedTo) `
                -DelegatedGrant (Read-Fixture oauth2PermissionGrants) -ServicePrincipal (Read-Fixture clientServicePrincipals))
    }

    It 'finds the app with full_access_as_app and the apps with EWS.AccessAsUser.All' {
        @($apps.id | Sort-Object) | Should -Be @('sp-backup', 'sp-crm')
    }
    It 'lists each app once with all its EWS permissions' {
        ($apps | Where-Object id -eq 'sp-backup').permissions | Should -Be 'full_access_as_app (application); EWS.AccessAsUser.All (delegated, one user)'
        ($apps | Where-Object id -eq 'sp-crm').permissions | Should -Be 'EWS.AccessAsUser.All (delegated, all users); EWS.AccessAsUser.All (delegated, one user)'
    }
    It 'ignores other Exchange app roles and grants without EWS' {
        $apps.id | Should -Not -Contain 'sp-other'
        $apps.id | Should -Not -Contain 'sp-portal'
    }
    It 'uses the service principal name and app ID' {
        ($apps | Where-Object id -eq 'sp-crm').displayName | Should -Be 'Contoso CRM'
        ($apps | Where-Object id -eq 'sp-crm').appId | Should -Be 'bbbb-crm'
    }
    It 'falls back to the assignment name when the service principal is unknown' {
        $only = @(Get-RetireEwsGrant -AppRoleAssignment (Read-Fixture appRoleAssignedTo))
        $only[0].displayName | Should -Be 'Old Backup Tool'
    }
}

Describe 'Markdown helpers' {
    It 'escapes pipes and angle brackets in table cells' {
        ConvertTo-RetireMarkdownCell 'a|b<script>' | Should -Be 'a\|b&lt;script&gt;'
    }
    It 'cuts long user tables and says how many were left out' {
        $users = 1..5 | ForEach-Object { [pscustomobject]@{ userPrincipalName = "u$_@x.com"; isAdmin = $false; methods = 'mobilePhone' } }
        $table = Format-RetireUserTable -User $users -MaximumRows 2
        ($table -split "`n" | Where-Object { $_ -clike '| u*@*' }).Count | Should -Be 2
        $table | Should -Match 'Showing 2 of 5 users'
    }
    It 'counts days to a date' {
        Get-RetireDaysUntil -Date '2027-02-01' -Now '2027-01-30' | Should -Be 2
        Get-RetireDaysUntil -Date '2027-02-01' -Now '2027-02-03' | Should -Be -2
    }
}

Describe 'MP.RETIRE.1001 phone-only users' {
    It 'fails and lists the users when some rely only on SMS or voice' {
        $script:Graph = @{ 'reports/authenticationMethods/userRegistrationDetails' = @(Read-Fixture userRegistrationDetails) }
        Test-RetirePhoneOnlyUser | Should -BeFalse
        $script:LastResult | Should -Match '^3 of 8 users rely only on SMS or voice'
        $script:LastResult | Should -Match 'amy@contoso.com'
    }
    It 'passes when no one relies only on SMS or voice' {
        $script:Graph = @{ 'reports/authenticationMethods/userRegistrationDetails' = @(Read-Fixture userRegistrationDetails | Where-Object id -in 'u2', 'u4') }
        Test-RetirePhoneOnlyUser | Should -BeTrue
        $script:LastResult | Should -Match '^Well done'
    }
}

Describe 'MP.RETIRE.1002 phone-only admins' {
    It 'fails and lists only the admins' {
        $script:Graph = @{ 'reports/authenticationMethods/userRegistrationDetails' = @(Read-Fixture userRegistrationDetails) }
        Test-RetirePhoneOnlyAdmin | Should -BeFalse
        $script:LastResult | Should -Match '^1 of 2 admins'
        $script:LastResult | Should -Match 'cara@contoso.com'
        $script:LastResult | Should -Not -Match 'amy@contoso.com'
    }
}

Describe 'MP.RETIRE.1003 EWS permissions' {
    It 'fails and lists the apps that hold EWS permissions' {
        $script:Graph = @{
            exchange             = @(Read-Fixture exchangeServicePrincipal)
            assignments          = @(Read-Fixture appRoleAssignedTo)
            oauth2PermissionGrants = @(Read-Fixture oauth2PermissionGrants)
            clients              = @(Read-Fixture clientServicePrincipals)
        }
        Test-RetireEwsPermission | Should -BeFalse
        $script:LastResult | Should -Match '^2 apps still hold Exchange Web Services permissions'
        $script:LastResult | Should -Match 'Contoso CRM'
    }
    It 'passes when no app holds an EWS permission' {
        $script:Graph = @{
            exchange               = @(Read-Fixture exchangeServicePrincipal)
            assignments            = @()
            oauth2PermissionGrants = @(Read-Fixture oauth2PermissionGrants | Where-Object id -eq 'g3')
            clients                = @(Read-Fixture clientServicePrincipals)
        }
        Test-RetireEwsPermission | Should -BeTrue
    }
    It 'skips when the tenant has no Exchange Online' {
        $script:Graph = @{ exchange = $null }
        $null = Test-RetireEwsPermission
        $script:LastSkip | Should -Be 'NotApplicable'
    }
}

Describe 'ConvertTo-RetireAppIdList' {
    It 'splits a comma-separated string and removes braces' {
        ConvertTo-RetireAppIdList -Value '{a1, b2}' | Should -Be @('a1', 'b2')
    }
    It 'removes duplicates regardless of case' {
        ConvertTo-RetireAppIdList -Value @('a1', 'A1', 'b2') | Should -Be @('a1', 'b2')
    }
    It 'returns nothing for null or empty values' {
        @(ConvertTo-RetireAppIdList -Value $null).Count | Should -Be 0
        @(ConvertTo-RetireAppIdList -Value @()).Count | Should -Be 0
        @(ConvertTo-RetireAppIdList -Value '').Count | Should -Be 0
    }
}

Describe 'Get-RetireEwsTenantState' {
    It 'treats an unset EwsEnabled as open to every app' {
        (Get-RetireEwsTenantState -EwsEnabled $null).State | Should -Be 'Open'
    }
    It 'treats EwsEnabled False as blocked, whatever the list says' {
        (Get-RetireEwsTenantState -EwsEnabled $false -AllowedAppId 'a1').State | Should -Be 'Blocked'
    }
    It 'treats EwsEnabled True with an empty list as blocked' {
        (Get-RetireEwsTenantState -EwsEnabled $true -AllowedAppId @()).State | Should -Be 'Blocked'
    }
    It 'returns the allowed apps for EwsEnabled True with a list' {
        $state = Get-RetireEwsTenantState -EwsEnabled $true -AllowedAppId 'a1', 'b2'
        $state.State | Should -Be 'AllowList'
        $state.AllowedAppId | Should -Be @('a1', 'b2')
    }
    It 'reads EwsEnabled given as text' {
        (Get-RetireEwsTenantState -EwsEnabled 'False').State | Should -Be 'Blocked'
        (Get-RetireEwsTenantState -EwsEnabled 'True' -AllowedAppId 'a1').State | Should -Be 'AllowList'
    }
    It 'says when the allow list could not be read' {
        (Get-RetireEwsTenantState -EwsEnabled $true -AllowListUnknown).State | Should -Be 'AllowListUnknown'
    }
}

Describe 'MP.RETIRE.1004 EWS tenant setting' {
    BeforeEach { $script:LastInvestigate = $false }

    It 'fails when EwsEnabled is not set' {
        Set-ExoFixture notSet
        Test-RetireEwsTenantSetting | Should -BeFalse
        $script:LastResult | Should -Match '^Every app can still use Exchange Web Services'
    }
    It 'passes when EWS is blocked' {
        Set-ExoFixture disabled
        Test-RetireEwsTenantSetting | Should -BeTrue
        $script:LastResult | Should -Match 'EwsEnabled is False'
    }
    It 'passes when EWS is on with an empty allow list' {
        Set-ExoFixture emptyList
        Test-RetireEwsTenantSetting | Should -BeTrue
        $script:LastResult | Should -Match 'EwsAllowedAppIDs is empty'
    }
    It 'fails and lists each allowed app once' {
        Set-ExoFixture allowList
        Test-RetireEwsTenantSetting | Should -BeFalse
        $script:LastResult | Should -Match '^2 apps are still allowed to use Exchange Web Services'
        $script:LastResult | Should -Match 'bbbbbbbb-0000-0000-0000-000000000002'
    }
    It 'reads the allow list when Exchange returns it as one string' {
        Set-ExoFixture allowString
        Test-RetireEwsTenantSetting | Should -BeFalse
        $script:LastResult | Should -Match '^2 apps are still allowed'
    }
    It 'asks to investigate when the Exchange module cannot read the allow list' {
        Set-ExoFixture allowList -OldModule
        Test-RetireEwsTenantSetting | Should -BeFalse
        $script:LastInvestigate | Should -BeTrue
        $script:LastResult | Should -Match 'cannot read the allowed app list'
    }
}
