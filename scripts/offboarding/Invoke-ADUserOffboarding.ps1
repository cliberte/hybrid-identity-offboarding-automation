# Hybrid Identity Lab - AD User Offboarding
# Author: Christian Liberte
# Environment: Personal IAM Lab

$ErrorActionPreference = 'Stop'

try {
    Import-Module ActiveDirectory

    # Jenkins parameter
    $Username = $env:AD_USERNAME

    # Lab configuration
    $SourceOU   = $env:AD_SOURCE_OU
    $TargetOU   = $env:AD_DISABLED_OU
    $GroupName  = $env:AD_OFFBOARD_GROUP
    $SyncServer = $env:ENTRA_SYNC_SERVER

    # Shared synchronization script
    $SyncScript = Join-Path $PSScriptRoot `
        '..\entra-sync\Invoke-EntraDeltaSync.ps1'

    if (-not (Test-Path -LiteralPath $SyncScript -PathType Leaf)) {
        throw 'Shared synchronization script not found.'
    }

    # Validate required parameter
    if ([string]::IsNullOrWhiteSpace($Username)) {
        throw 'AD_USERNAME parameter cannot be empty.'
    }

    $Username = $Username.Trim()

    # Validate environment configuration
    if (-not $SourceOU -or -not $TargetOU -or
        -not $GroupName -or -not $SyncServer) {
        throw 'Required environment configuration is missing.'
    }

    if ($SourceOU -eq $TargetOU) {
        throw 'Source and destination OUs must be different.'
    }

    Write-Host "Starting offboarding for: $Username"

    # Validate destination OU and security group
    Get-ADOrganizationalUnit -Identity $TargetOU | Out-Null
    $Group = Get-ADGroup -Identity $GroupName

    # Locate user within the managed Users OU
    $User = Get-ADUser `
        -Filter {SamAccountName -eq $Username} `
        -SearchBase $SourceOU `
        -SearchScope OneLevel `
        -Properties MemberOf

    $AlreadyInTargetOU = $false

    # Allow recovery of an already disabled account
    if (-not $User) {
        $User = Get-ADUser `
            -Filter {SamAccountName -eq $Username} `
            -SearchBase $TargetOU `
            -SearchScope OneLevel `
            -Properties MemberOf

        if (-not $User -or $User.Enabled) {
            throw 'User not found in an approved offboarding state.'
        }

        $AlreadyInTargetOU = $true
    }

    Write-Host 'Managed OU boundary verified.'

    # Disable the AD account
    if ($User.Enabled) {
        Disable-ADAccount -Identity $User.ObjectGUID
        Write-Host 'AD account disabled.'
    }
    else {
        Write-Host 'Account already disabled.'
    }

    # Remove managed security group membership
    if ($User.MemberOf -contains $Group.DistinguishedName) {
        Remove-ADGroupMember `
            -Identity $Group `
            -Members $User `
            -Confirm:$false

        Write-Host "Removed from group: $GroupName"
    }
    else {
        Write-Host "Not a member of $GroupName - skipping."
    }

    # Move user to Disabled Users OU
    if (-not $AlreadyInTargetOU) {
        Move-ADObject `
            -Identity $User.ObjectGUID `
            -TargetPath $TargetOU

        Write-Host 'User moved to Disabled Users OU.'
    }

    # Verify final Active Directory state
    $FinalUser = Get-ADUser `
        -Filter {SamAccountName -eq $Username} `
        -SearchBase $TargetOU `
        -SearchScope OneLevel `
        -Properties MemberOf

    if (-not $FinalUser) {
        throw 'Verification failed: Incorrect OU location.'
    }

    if ($FinalUser.Enabled) {
        throw 'Verification failed: Account is still enabled.'
    }

    if ($FinalUser.MemberOf -contains $Group.DistinguishedName) {
        throw 'Verification failed: Group membership remains.'
    }

    Write-Host 'On-premises AD verification successful.'

    # Trigger Entra Connect delta synchronization
    Write-Host 'Triggering Entra Connect delta sync...'

    # Execute shared synchronization script
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SyncScript

    if ($LASTEXITCODE -ne 0) {
        throw 'Shared synchronization script failed.'
    }

    Write-Host '-----------------------------------'
    Write-Host "OFFBOARDING SUCCESSFUL: $Username"
    Write-Host "Enabled: $($FinalUser.Enabled)"
    Write-Host 'Location: Disabled Users OU'
    Write-Host 'Delta sync request: SUCCESS'
    Write-Host 'Cloud account verification required.'
    Write-Host '-----------------------------------'

    exit 0
}
catch {
    Write-Host "OFFBOARDING FAILED: $($_.Exception.Message)"
    exit 1
}
