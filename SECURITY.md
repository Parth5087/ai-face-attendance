# Security Policy

## 🔒 Supported Versions

The following versions of **AI Face Attendance** currently receive security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

---

## 🛡️ Privacy & Biometric Data Safeguards

This application is engineered with **Privacy-by-Design** and **Zero-Trust Local Storage** principles:

1. **Zero Cloud Transmission**:
   - The application does not require internet connectivity and makes zero outbound network calls.
   - All facial embeddings and biometric data remain localized to the host device sandbox.

2. **No Raw Imagery Retention**:
   - Camera video frames are processed in transient memory solely to extract 192-dimensional floating-point vectors.
   - Raw facial photos are never written to disk, ensuring full compliance with GDPR and biometric data protection regulations.

3. **Anti-Spoofing & Liveness Protection**:
   - Active presentation attack detection prevents photographic, video-replay, and screen spoofing attacks.

---

## 🚨 Reporting a Vulnerability

If you discover a security vulnerability or security bug, please report it privately:

- **Email**: [parthpatel5087@gmail.com](mailto:parthpatel5087@gmail.com)
- **Subject**: `[SECURITY VULNERABILITY] AI Face Attendance`

Please include detailed steps to reproduce the issue. We take security seriously and will acknowledge receipt within 48 hours.
