# Hybrid Identity Lab - AD User Provisioning
# Author: Christian Liberte
# Environment: Personal IAM Lab

$ErrorActionPreference = 'Stop'

try {
    Import-Module ActiveDirectory

    # Jenkins parameters
    $FirstName = $env:FIRST_NAME
    $LastName  = $env:LAST_NAME
    $Username  = $env:USERNAME
    $GroupName = $env:GROUP_NAME

    # Lab configuration
    $UPNSuffix  = $env:AD_UPN_SUFFIX
    $TargetOU   = $env:AD_TARGET_OU
    $SyncServer = $env:ENTRA_SYNC_SERVER

    # Validate environment configuration
    if (-not $UPNSuffix -or -not $TargetOU -or -not $SyncServer) {
    throw 'Required environment configuration is missing.'
    }
    # Validate required Jenkins parameters
    if (-not $FirstName -or -not $LastName -or
        -not $Username -or -not $GroupName) {
        throw 'Required Jenkins parameters are missing.'
    }
    if (-not $env:INITIAL_PASSWORD) {
        throw 'Initial password credential is missing.'
    }

    # User attributes
    $DisplayName = "$FirstName $LastName"
    $UPN = "$Username@$UPNSuffix"

    # Retrieve password from Jenkins Credentials
    $Password = ConvertTo-SecureString `
        $env:INITIAL_PASSWORD -AsPlainText -Force

    # Prevent modification of an existing account
    if (Get-ADUser -Filter {SamAccountName -eq $Username}) {
        throw "User already exists: $Username"
    }

    # Validate target group
    $Group = Get-ADGroup -Identity $GroupName

    # Create Active Directory user
    New-ADUser `
        -Name $DisplayName `
        -GivenName $FirstName `
        -Surname $LastName `
        -SamAccountName $Username `
        -UserPrincipalName $UPN `
        -Path $TargetOU `
        -AccountPassword $Password `
        -Enabled $true

    Write-Host "User created successfully: $Username"

    # Assign security group
    Add-ADGroupMember -Identity $Group -Members $Username

    # Validate account and group membership
    $User = Get-ADUser -Identity $Username -Properties MemberOf

    if (-not $User.Enabled) {
        throw 'Account is not enabled.'
    }

    if ($User.MemberOf -notcontains $Group.DistinguishedName) {
        throw 'Security group assignment failed validation.'
    }

    Write-Host "Group membership verified: $GroupName"

    $User | Select-Object Name, SamAccountName,
        UserPrincipalName, Enabled

    Get-ADPrincipalGroupMembership $Username |
        Select-Object Name

    # Request Microsoft Entra Connect delta synchronization
    Write-Host 'Requesting Microsoft Entra Connect delta sync...'

    Invoke-Command -ComputerName $SyncServer -ScriptBlock {
        $ErrorActionPreference = 'Stop'
        Import-Module ADSync
        Start-ADSyncSyncCycle -PolicyType Delta
    }

    Write-Host 'Provisioning workflow completed.'
    exit 0
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    exit 1
}
