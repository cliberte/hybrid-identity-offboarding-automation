# Hybrid Identity Lab — IAM Lifecycle Automation

## 📌 Project Overview

A personal IAM engineering project demonstrating hybrid identity
management, automated user provisioning and offboarding,
least-privilege access, and synchronization between Active Directory
and Microsoft Entra ID using PowerShell and Jenkins.

**Project Status:** Completed and operational.
Technical documentation is being progressively added to this repository.

## 🛠️ Technologies Used

- Windows Server 2022
- Active Directory Domain Services (AD DS)
- Microsoft Entra ID
- Microsoft Entra Connect Sync
- Password Hash Synchronization (PHS)
- PowerShell
- Jenkins
- VMware Workstation
- Kerberos and WinRM

## 🏗️ Lab Architecture

| Server | Role |
| --- | --- |
| DC01 | Active Directory Domain Services and DNS |
| AADCONNECT01 | Microsoft Entra Connect Sync |
| JENKINS01 | Identity lifecycle automation |
| Microsoft Entra ID | Cloud identity management |

[View the detailed lab architecture and workflow diagram](docs/architecture.md)

## ⚙️ Implemented Features

### User Provisioning

- Parameterized Jenkins and PowerShell automation
- Active Directory user account creation
- Security group assignment
- Organizational Unit (OU) placement
- Identity synchronization to Microsoft Entra ID

### User Offboarding

- Automated Active Directory account disablement
- Security group membership removal
- Movement to a dedicated Disabled Users OU
- Post-action validation
- Microsoft Entra Connect delta synchronization
- Cloud account status verification

## 🔐 Security and Least-Privilege Design

- Dedicated Jenkins service account
- Delegated Active Directory permissions
- Organizational Unit-based permission boundaries
- ADSyncOperators permissions
- Kerberos-authenticated PowerShell remoting
- Explicit error handling and validation
- Jenkins build failure reporting

## ✅ Testing and Validation

- Successful test user provisioning
- Active Directory account disablement verified
- Security group removal verified
- Disabled Users OU placement verified
- Entra Connect delta synchronization validated
- Disabled account state verified in Microsoft Entra ID
- Jenkins success and failure handling validated

## 🎯 Skills Demonstrated

- Hybrid Identity Engineering
- Identity Lifecycle Management
- Identity and Access Management (IAM)
- Active Directory Administration
- Microsoft Entra ID Administration
- PowerShell Automation
- Jenkins Automation
- Least-Privilege Access
- Hybrid Identity Troubleshooting

## 📝 Maintenance log

- [2026-11-19 — Hybrid identity lab maintenance and Windows 11 26H2 upgrade](docs/maintenance/2026-11-19-hybrid-identity-lab.md)

## 👤 Author

Christian Liberté

Identity & Access Management Specialist | SC-300 | Security+
