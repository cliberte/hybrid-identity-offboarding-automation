# Hybrid Identity Lab — maintenance and troubleshooting

**Date:** 2026-11-19  
**Environment:** Personal IAM engineering lab (non-production)  
**Change:** Host storage and OS maintenance, hybrid identity recovery, and regression testing  
**Outcome:** Windows 11 26H2 installed; core lab services operational after restart.

## 1. Objectives and environment

- Protect the existing lab configuration before a host feature upgrade.
- Restore and validate Active Directory, Microsoft Entra Connect Sync, and Jenkins.
- Exercise the joiner and leaver workflows from on-premises AD through Microsoft Entra ID.
- Record evidence, known limitations, and the recovery approach.

| System | Responsibility |
| --- | --- |
| HP Z2 Tower G4 workstation | VMware Workstation host; Intel Core i7-8700; Samsung 990 PRO 1 TB NVMe |
| DC01 | Windows Server 2022, Active Directory Domain Services and DNS |
| AADCONNECT01 | Microsoft Entra Connect Sync, Password Hash Synchronization (PHS), cloud synchronization |
| JENKINS01 | Jenkins and PowerShell automation using a delegated service account |

The domain, tenant identifiers, network addresses, object IDs, credential material, and certificate identifiers are deliberately omitted.

## 2. Maintenance and troubleshooting record

### 2.1 Host and Windows Server servicing

- Migrated the host storage to a 1 TB NVMe SSD as part of the workstation maintenance.
- Repaired/serviced Windows 11 Pro 25H2 and confirmed the host was running before the feature upgrade.
- Reviewed Windows Server evaluation licensing. The license status was licensed, but the evaluation remained time-limited; this was not a permanent activation.
- Checked lab services before attempting the host feature upgrade.

### 2.2 DNS and Entra Connect authentication recovery

**Symptoms:** Entra Connect could not validate credentials. Its error identified an inability to resolve `login.microsoftonline.com`. On AADCONNECT01, DNS requests for both the Microsoft endpoint and the domain controller timed out.

**Finding:** DC01, which supplies DNS to the lab, was powered off. This explained the missing name resolution and blocked the configuration workflow.

**Resolution:** Started DC01 and allowed AD DS/DNS to initialize before retrying Entra Connect. The connector configuration wizard became accessible again. Subsequent TCP 443 tests to Microsoft sign-in and Graph endpoints succeeded.

Representative diagnostics (run on AADCONNECT01):

```powershell
Resolve-DnsName login.microsoftonline.com
Resolve-DnsName <DC01-FQDN>
Test-NetConnection login.microsoftonline.com -Port 443
Test-NetConnection graph.microsoft.com -Port 443
```

**Lesson:** Restore foundational DNS and directory services before troubleshooting cloud authentication. A credential-validation error can originate from network name resolution rather than invalid credentials.

### 2.3 Entra Connect certificate rotation and import recovery

- Rotated the Entra Connect application authentication certificate using its configuration wizard. The wizard reported successful completion.
- The wizard recommended a TPM. Event logs showed a TPM-backed key creation failure and successful creation using the software key storage provider. TPM-backed certificate protection remains a hardening opportunity; the warning did not invalidate the completed rotation.
- Confirmed the ADSync scheduler was enabled, with a 30-minute effective synchronization interval and staging mode disabled.
- Observed repeated cloud connector Delta Import failures with status `stopped-server-down`, while other import, synchronization, and export steps succeeded.
- Reviewed Windows Application event logs. Event IDs 109, 6803 and 6110 reported an internal cloud import error (code 78) and an unsaved import watermark. A successful HTTPS connectivity test alone did not establish import health.
- Ran a Full Import on the Microsoft Entra connector in Synchronization Service Manager. The run returned `success`. Subsequent synchronization testing succeeded, and a new AD identity appeared in Entra ID.

The Full Import restored the observed import operation; a stale or invalid incremental import state was a possible explanation, not a proven root cause.

Representative diagnostics:

```powershell
Import-Module ADSync
Get-ADSyncScheduler
Get-Service ADSync
Start-ADSyncSyncCycle -PolicyType Delta
```

Review the Operations tab in Synchronization Service Manager after submitting a synchronization cycle. A successful command submission is not equivalent to a completed synchronization run.

## 3. Pre-upgrade regression testing

### 3.1 Active Directory and Jenkins

| Check | Observed result |
| --- | --- |
| Jenkins Windows service | Running |
| Jenkins computer secure channel | True; domain trust healthy |
| LDAP connectivity from Jenkins to DC01 (TCP 389) | Successful |
| Jenkins execution, AD access and AD PowerShell access tests | SUCCESS reported |
| Jenkins Entra Connect delta sync trigger | SUCCESS reported |

Representative diagnostics (run on JENKINS01):

```powershell
Get-Service Jenkins
Test-ComputerSecureChannel -Verbose
Test-NetConnection <DC01-FQDN> -Port 389
```

### 3.2 End-to-end identity lifecycle test

Created a disposable maintenance test identity through the parameterized Jenkins provisioning job.

| Stage | Evidence |
| --- | --- |
| Provisioning | User created in the automation Users OU; account enabled; expected UPN format |
| AD group assignment | Direct membership observed in the Helpdesk test security group |
| Cloud synchronization | Corresponding enabled member account appeared in Entra ID |
| Offboarding | Jenkins workflow executed; AD user disabled, moved to the Disabled Users OU and direct group memberships removed |
| Cloud offboarding | Successful completion reported by the lab operator |

Verification commands (run on DC01; replace the placeholder with the disposable test account):

```powershell
Get-ADUser -Identity <test-username> -Properties MemberOf |
    Select-Object Name,Enabled,UserPrincipalName,DistinguishedName,MemberOf |
    Format-List
```

**Validation caveat:** The provisioning form requested the IT test group, but the AD query displayed membership in the Helpdesk test group. Although the end-to-end account workflow worked, exact parameter-to-group mapping was not established by this test. Investigate the provisioning script's group parameter handling and repeat the test with a known expected group before claiming correct group assignment. Empty `MemberOf` after offboarding confirms no direct groups listed by that attribute; it does not prove removal of the primary group or every effective permission.

## 4. Backup and host feature upgrade

### 4.1 Recovery preparation

Prepared a cold VM backup before the upgrade. Fully shut down the VMs in dependency-reverse order:

1. JENKINS01
2. AADCONNECT01
3. DC01

The backup approach is to copy each complete VMware VM folder, including configuration and all dependent virtual disk/snapshot files, ideally onto a separate physical drive. Retain the original pre-upgrade copies. Backup integrity verification and a recovery boot in an isolated environment were not independently recorded; these remain follow-up actions.

### 4.2 Windows 11 26H2 upgrade investigation

The feature update initially did not appear in Windows Update.

| Diagnostic | Observed result |
| --- | --- |
| Windows Update policy registry | No target release version restriction found |
| CPU | Intel Core i7-8700 |
| TPM | Present, ready, enabled; specification version 2.0 |
| Secure Boot | True |
| Generic Appraiser safeguard status | GStatus = 2 (no hold indicated by that value) |
| Compatibility scheduled task | Existing `Microsoft Compatibility Appraiser Exp` executed; LastTaskResult = 0 |

The earlier TPM and Secure Boot checks failed without elevation. Running them from Administrator PowerShell established the correct state. No BIOS changes or TPM clearing were required.

Representative commands (host, Administrator PowerShell):

```powershell
Get-CimInstance Win32_Processor | Select-Object Name
Get-Tpm
Confirm-SecureBootUEFI
Get-CimInstance -Namespace root\CIMV2\Security\MicrosoftTpm -ClassName Win32_Tpm |
    Select-Object SpecVersion
Get-ScheduledTask -TaskPath "\Microsoft\Windows\Application Experience\" |
    Select-Object TaskName,State
Start-ScheduledTask -TaskPath "\Microsoft\Windows\Application Experience\" -TaskName "Microsoft Compatibility Appraiser Exp"
Get-ScheduledTask -TaskName "Microsoft Compatibility Appraiser Exp" |
    Get-ScheduledTaskInfo
```

After the assessment and restart, the official Windows Installation Assistant reported that the newest version was already installed. Running `winver` verified:

- **Windows 11 Pro, version 26H2**
- **OS build 26300.10075**

The exact mechanism/timing of the feature upgrade was not captured. No manual compatibility bypass or clean installation was needed.

## 5. Post-upgrade validation and outcome

Started the VMs in dependency order (DC01 → AADCONNECT01 → JENKINS01), allowing each to initialize before the next.

| Item | Status |
| --- | --- |
| Windows 11 26H2 host | Verified with winver |
| VMware Workstation and virtual machines | Operational, reported after restart |
| AD DS/DNS, Entra Connect and Jenkins | Operational, reported after validation |
| Provisioning and offboarding | Successfully exercised before host upgrade; operator reported post-upgrade environment working |
| Backup restore test | Not yet performed |
| Exact provisioning group mapping | Follow-up required |

The Server Manager recommendation to try Windows Admin Center and Azure Arc was informational and not a fault; no new Azure Arc configuration was introduced.

**Change result:** Host upgrade completed; core hybrid identity environment remained operational. Retain backups and perform a repeatable regression test after future changes.

## 6. Follow-up and continuous improvement

- [ ] Verify backup file counts/sizes or hashes and retain a copy on a separate physical disk.
- [ ] Establish regular AD System State backups and document an isolated recovery test.
- [ ] Export and securely retain Entra Connect configuration and document certificate expiry/rotation monitoring.
- [ ] Investigate TPM-backed Entra Connect application certificate storage in the VM.
- [ ] Resolve the IT vs Helpdesk test-group assignment discrepancy and verify cloud membership on future tests.
- [ ] Repeat and capture a complete post-upgrade joiner/leaver test (including cloud account state and group membership).
- [ ] Document a recurring VM backup and maintenance cadence.

## 7. Skills demonstrated

- Hybrid identity dependency troubleshooting and DNS diagnostics
- Application certificate lifecycle and Entra Connect operational troubleshooting
- Event log analysis, connector run history, synchronization validation
- Delegated AD automation, identity provisioning and deprovisioning
- Change preparation, cold VM backup planning and post-change verification

## References

- [VMware Workstation VM backup guidance (Broadcom)](https://knowledge.broadcom.com/external/article?legacyId=2006202)
- [Microsoft: Restore a virtualized domain controller](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/virtual-dc/restore-virtualized-domain-controller)
- [Microsoft: Windows safeguard holds](https://learn.microsoft.com/en-us/windows/deployment/update/safeguard-holds)
- [Microsoft: Windows 11 release information](https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information)
