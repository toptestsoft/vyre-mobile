# Privacy Policy

VYRE VPN does not collect, store or transmit any personal data or logs.

- **No logs**: Connection logs, IP addresses, and browsing activity are never stored.
- **Local storage only**: Subscriptions and credentials are stored encrypted on-device using flutter_secure_storage.
- **No third-party analytics**: No tracking, no ads, no data sharing with third parties.
- **Open-source**: Full source code available at [github.com/toptestsoft/vyre-mobile](https://github.com/toptestsoft/vyre-mobile).

## Security mechanisms

- **Config validation**: Every subscription config is checked before use. Unsupported protocols and private/local IPs are rejected to prevent malicious or SSRF-like configs.
- **Config normalization**: DNS traffic is forced through secure resolvers (1.1.1.1 / 8.8.8.8). IPv6 and WebRTC/STUN traffic is blocked to reduce leak surface.
- **Encrypted cache**: Subscription bodies are stored in FlutterSecureStorage with AES-GCM encryption and SHA-256 anonymized keys.
- **Network hardening**: Subscription fetches enforce HTTPS downgrade protection, redirect limits, timeouts, and response size limits.

For questions: contact via toptestsoft@gmail.com
