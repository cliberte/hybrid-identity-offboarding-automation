# Jenkins Configuration — Hybrid Identity Lab

## 1. Overview

Three Jenkins jobs automate hybrid identity lifecycle operations using PowerShell.

| Jenkins job | Responsibility |
| --- | --- |
| Lab - Create AD Test User | User provisioning |
| Lab - Offboard AD Test User | User offboarding |
| Lab - Trigger Entra Connect Delta Sync | On-demand synchronization |

## 2. Script deployment

All three scripts are deployed on JENKINS01.

```text
C:\IAM-Lab\Scripts\
├── Provisioning\
│   └── New-ADTestUser.ps1
├── Offboarding\
│   └── Invoke-ADUserOffboarding.ps1
└── Entra-Sync\
    └── Invoke-EntraDeltaSync.ps1
```

The Jenkins build commands execute these local scripts. They do not automatically download them from GitHub.

The relative directory structure must be preserved because both lifecycle scripts reference the shared synchronization script.

The batch commands below use example domain identifiers. Replace them with the intended environment's UPN suffix, OU distinguished names and synchronization server FQDN. No password values are included.

## 3. User provisioning

**Job:** Lab - Create AD Test User

| Parameter | Type | Default value |
| --- | --- | --- |
| FIRST_NAME | String | John |
| LAST_NAME | String | Test |
| USERNAME | String | jtest2 |
| GROUP_NAME | Choice | GG_IT_Users |

Available security groups:

- GG_IT_Users
- GG_Helpdesk_Users
- GG_Finance_Users
- GG_HR_Users

### Credential binding

| Setting | Value |
| --- | --- |
| Credential type | Secret text |
| Credential ID | ad-initial-password |
| Environment variable | INITIAL_PASSWORD |
| Description | AD Test User Initial Password |

### Build command

```batch
@echo off

set "AD_UPN_SUFFIX=example.com"
set "AD_TARGET_OU=OU=Users,OU=JenkinsAutomation,DC=lab,DC=example,DC=com"
set "ENTRA_SYNC_SERVER=aadconnect01.lab.example.com"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\IAM-Lab\Scripts\Provisioning\New-ADTestUser.ps1"

exit /b %ERRORLEVEL%
```

## 4. User offboarding

**Job:** Lab - Offboard AD Test User

| Parameter | Type | Default value |
| --- | --- | --- |
| AD_USERNAME | String | Blank |

Concurrent builds are disabled.

### Build command

```batch
@echo off

set "AD_SOURCE_OU=OU=Users,OU=JenkinsAutomation,DC=lab,DC=example,DC=com"
set "AD_DISABLED_OU=OU=Disabled Users,OU=JenkinsAutomation,DC=lab,DC=example,DC=com"
set "AD_OFFBOARD_GROUP=GG_Helpdesk_Users"
set "ENTRA_SYNC_SERVER=aadconnect01.lab.example.com"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\IAM-Lab\Scripts\Offboarding\Invoke-ADUserOffboarding.ps1"

exit /b %ERRORLEVEL%
```

## 5. Entra Connect delta synchronization

**Job:** Lab - Trigger Entra Connect Delta Sync

No user input is required by the script.

### Build command

```batch
@echo off

set "ENTRA_SYNC_SERVER=aadconnect01.lab.example.com"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\IAM-Lab\Scripts\Entra-Sync\Invoke-EntraDeltaSync.ps1"

exit /b %ERRORLEVEL%
```

The standalone job allows authorized operators to request synchronization on demand. Provisioning and offboarding already invoke the same synchronization script automatically.

## 6. Security controls

| Control | Implementation |
| --- | --- |
| Least privilege | Dedicated Jenkins service account and delegated permissions |
| Secrets management | Jenkins Credentials |
| Authentication | Kerberos |
| Safety boundaries | Managed Active Directory OUs |
| Error handling | PowerShell try/catch and exit codes |
| Input constraint | Predefined security group choices |
| Idempotency | Safe repetition of offboarding |
| Modular design | Shared synchronization script |

## 7. Testing and validation

| Validation test | Result |
| --- | --- |
| User provisioning | Passed |
| Security group assignment | Passed |
| Duplicate account prevention | Passed |
| Missing parameter validation | Passed |
| User offboarding | Passed |
| Repeated offboarding | Passed |
| OU safety boundary | Passed |
| Standalone delta synchronization | Passed |
| Cloud account state verification | Passed |

## 8. Operational limitations

- Offboarding removes only the configured security group.
- Synchronization request success does not guarantee successful cloud export.
- Cloud account verification remains a separate operation.
- Provisioning failures may require inspection of partially completed AD changes before retrying.
