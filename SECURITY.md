# Security Policy

Because **OSCraft** interfaces directly with storage partitions, filesystem structures, and Linux kernel APIs (`kexec`, UEFI NVRAM), security and data integrity are top priorities.

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.0.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security issue or vulnerability that could cause data corruption, unauthorized privilege escalation, or bootloader failure:

1. **Do not create a public issue**.
2. Submit a confidential report via **GitHub Advisory** on the repository page (`Security` -> `Advisories` -> `Report a vulnerability`).
3. Alternatively, reach out directly to the maintainer via the email associated with the GitHub account `Judeadeniji`.

### What to Include

- Detailed description of the vulnerability and its potential impact.
- Step-by-step reproduction instructions or a minimal test case.
- Any proposed fix or mitigation, if available.

We will review your submission promptly, validate the issue, and coordinate a fix prior to public disclosure.
