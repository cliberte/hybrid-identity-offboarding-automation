# Hybrid Identity Lab - Entra Connect Delta Synchronization
# Author: Christian Liberte
# Environment: Personal IAM Lab

$ErrorActionPreference = 'Stop'

try {
    # Lab configuration
    $SyncServer = $env:ENTRA_SYNC_SERVER

    # Validate environment configuration
    if ([string]::IsNullOrWhiteSpace($SyncServer)) {
        throw 'ENTRA_SYNC_SERVER configuration is missing.'
    }

    $SyncServer = $SyncServer.Trim()

    Write-Host 'Connecting to Entra Connect server...'

    # Request delta synchronization using Kerberos
    $Result = Invoke-Command `
        -ComputerName $SyncServer `
        -Authentication Kerberos `
        -ScriptBlock {
            $ErrorActionPreference = 'Stop'

            Import-Module ADSync

            Write-Host 'Starting Entra Connect delta sync...'

            Start-ADSyncSyncCycle `
                -PolicyType Delta `
                -InteractiveMode $false
        }

    # Validate synchronization request
    if ($Result.Result -ne 'Success') {
        throw "Delta sync request failed. Result: $($Result.Result)"
    }

    Write-Host '-----------------------------------'
    Write-Host 'DELTA SYNC REQUEST SUCCESSFUL'
    Write-Host 'Cloud synchronization verification required.'
    Write-Host '-----------------------------------'

    exit 0
}
catch {
    Write-Host "ENTRA CONNECT SYNC FAILED: $($_.Exception.Message)"
    exit 1
}
