# Hybrid Identity Lab — Testing and Validation

## 1. Objective

Validate automated identity lifecycle management across Jenkins, Active Directory and Microsoft Entra ID, including successful operations, error handling and security controls.

## 2. Positive testing

| ID | Test | Test account | Result |
| --- | --- | --- | --- |
| PT-01 | Credential integration | credtest01 | Passed |
| PT-02 | External PowerShell execution | autotest01 | Passed |
| PT-03 | Externalized configuration | configtest01 | Passed |
| PT-04 | Shared synchronization integration | modulartest01 | Passed |
| PT-05 | End-to-end offboarding | modulartest01 | Passed |
| PT-06 | Standalone delta sync | N/A | Passed |

## 3. Negative testing

| ID | Test scenario | Expected outcome | Result |
| --- | --- | --- | --- |
| NT-01 | Duplicate username | Reject account creation | Passed |
| NT-02 | Missing provisioning parameters | Reject incomplete request | Passed |
| NT-03 | Missing sync server configuration | Reject synchronization request | Passed |
| NT-04 | Account outside managed OUs | Reject offboarding request | Passed |

All four scenarios correctly produced failure statuses during testing.

## 4. Security boundary validation

The offboarding job was executed against ouboundary01, an account located outside the approved OU hierarchy.

The script rejected the operation:

```text
OFFBOARDING FAILED: User not found in an approved offboarding state.
```

**Result:** Passed (NT-04).

## 5. Idempotency validation

The offboarding job was executed twice against configtest01.

The second execution recognized the existing disabled state and skipped completed AD operations while successfully requesting synchronization.

**Result:** Passed (IT-01).

## 6. End-to-end identity lifecycle validation

The account modulartest01 was successfully provisioned and subsequently offboarded.

| Identity attribute | Provisioned | Offboarded |
| --- | --- | --- |
| AD account enabled | Yes | No |
| AD Helpdesk group membership | Present | Removed |
| Organizational Unit | Users | Disabled Users |
| Entra ID account enabled | Yes | No |
| On-premises synchronization enabled | Yes | Yes |

Successful synchronization operations were also verified through Synchronization Service Manager.

## 7. Validation summary

| Metric | Result |
| --- | --- |
| Test scenarios | 11 |
| Passed | 11 |
| Failed tests | 0 |
| Pass rate | 100% |

Results apply to the 11 documented scenarios tested throughout the lab's development. The security boundary validation and end-to-end lifecycle evidence provide details for tests already counted in the positive and negative test matrices.

## 8. Validation limitations

- Offboarding removes only the configured security group.
- Cloud session revocation is not currently implemented.
- Successful synchronization requests require separate cloud state verification.
- Testing was performed in a personal, non-production lab.
