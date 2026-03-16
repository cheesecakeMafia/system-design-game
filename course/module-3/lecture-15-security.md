# Lecture 15: Security Fundamentals for System Design

> Module 3 — "The Distributed Mind" | Lecture 15 of 20

Security isn't a feature — it's a property of every component in your system. In system design interviews, ignoring security is a red flag. This lecture covers the security concepts you need at the architectural level: authentication, authorization, common attack vectors, and encryption.

---

## Pre-Reading

**Read these sections from the [System Design Primer](../../deps/system-design-primer/README.md) before starting this lecture:**

- *Security*

---

## Deep Dive

### AuthN vs AuthZ

**Authentication (AuthN):** "Who are you?" — Verifying identity.
**Authorization (AuthZ):** "What can you do?" — Verifying permissions.

These are separate concerns. A user can be authenticated (we know who they are) but not authorized (they don't have permission for this action).

#### Authentication Methods

| Method | How It Works | Best For |
|--------|-------------|----------|
| **API Key** | Long-lived token in header | Server-to-server, simple integrations |
| **JWT (JSON Web Token)** | Signed token containing user claims | Stateless authentication, microservices |
| **OAuth 2.0** | Delegated authorization framework | "Login with Google," third-party access |
| **Session cookies** | Server stores session, client holds session ID | Traditional web apps |
| **mTLS** | Both client and server verify certificates | Service-to-service in zero trust |

**JWT Deep Dive:**
```
Header.Payload.Signature

Header:  {"alg": "RS256", "typ": "JWT"}
Payload: {"user_id": 42, "role": "admin", "exp": 1679356800}
Signature: RS256(header + payload, private_key)
```

| Pros | Cons |
|------|------|
| Stateless — no server-side session store needed | Can't be revoked until expiry (no server-side state) |
| Self-contained — carries user info | Gets large with many claims |
| Works across microservices | Token theft = full access until expiry |

**OAuth 2.0 flows:**
- **Authorization Code** — For server-side apps. Most secure.
- **PKCE** — For mobile/SPA apps. Prevents code interception.
- **Client Credentials** — For machine-to-machine. No user involved.

### Common Attack Vectors and Defenses

#### DDoS (Distributed Denial of Service)

Overwhelm the system with traffic so legitimate users can't access it.

**Architectural defenses:**
- **CDN/WAF** — Cloudflare, AWS Shield absorb attack traffic at the edge
- **Rate limiting** — Per-IP and per-user limits (connects to Lecture 14)
- **Auto-scaling** — Scale up to absorb legitimate traffic spikes
- **Geographic filtering** — Block traffic from regions where you have no users
- **Anycast routing** — Distribute attack traffic across multiple edge locations

#### Injection Attacks (SQL, NoSQL, Command)

Malicious input executed as code.

```sql
-- User input: ' OR '1'='1' --
SELECT * FROM users WHERE username = '' OR '1'='1' --'
-- Returns ALL users!
```

**Defense:** Parameterized queries. Never concatenate user input into queries.
```python
# BAD:  cursor.execute(f"SELECT * FROM users WHERE id = {user_input}")
# GOOD: cursor.execute("SELECT * FROM users WHERE id = %s", (user_input,))
```

#### Man-in-the-Middle (MITM)

Attacker intercepts communication between client and server.

**Defense:** TLS everywhere. HTTPS for all external traffic. mTLS for internal service-to-service.

#### CSRF (Cross-Site Request Forgery)

Attacker tricks a user's browser into making requests to your site using the user's cookies.

**Defense:** CSRF tokens. The server includes a random token in forms; the request must include this token to be valid.

### Rate Limiting as Security

Rate limiting (from Lecture 14) is also a security mechanism:

| Attack | How Rate Limiting Helps |
|--------|------------------------|
| Brute-force login | Limit login attempts per IP/account |
| DDoS | Limit total requests per IP |
| Credential stuffing | Limit authentication attempts |
| Scraping | Limit API calls per API key |
| API abuse | Limit expensive operations separately |

### Encryption

**At rest:** Data stored on disk is encrypted. If someone steals the hard drive, they can't read the data.
- Database encryption (TDE — Transparent Data Encryption)
- File system encryption (LUKS, BitLocker)
- Application-level encryption (encrypt specific fields before storing)

**In transit:** Data moving across the network is encrypted.
- TLS 1.3 for all external traffic
- mTLS for internal service-to-service
- Certificate management (Let's Encrypt, AWS ACM)

**End-to-end:** Only the sender and receiver can read the data. Not even the server.
- Messaging apps (Signal protocol)
- Not applicable for most system designs (server needs to process the data)

### Zero Trust Architecture

Traditional: "Trust everything inside the network perimeter."
Zero trust: "Never trust, always verify."

**Principles:**
1. **Verify explicitly** — Authenticate and authorize every request, even internal
2. **Least privilege** — Give minimum permissions needed
3. **Assume breach** — Design as if attackers are already inside the network

**Implementation:** mTLS between all services, per-request authorization, network segmentation, encrypted data at rest and in transit.

### Security in System Design Interviews

Interviewers expect you to mention:
1. **HTTPS** for all external communication
2. **Authentication** — how users prove identity
3. **Authorization** — how you control access to resources
4. **Rate limiting** — protect against abuse
5. **Input validation** — never trust user input
6. **Encryption** — at rest for sensitive data, in transit everywhere

You don't need to design a full security architecture, but completely ignoring security signals inexperience.

---

## Field Ops: Server Survival

In the game, the **Firewall** service blocks `MALICIOUS` traffic (representing DDoS attacks).

Observe:
- What happens when 50% of traffic is malicious and you have no Firewall? Your Compute and DB are overwhelmed by fake requests.
- Place a Firewall at the entry point. Watch how it filters malicious traffic before it reaches your infrastructure.
- The Queue's capacity limit acts as a rate limiter — when the queue is full, excess requests are dropped.

This is defense in depth: Firewall (blocks bad traffic) → Queue (limits rate) → Compute (processes only legitimate, rate-limited requests).

---

## Knowledge Check

Record your score in [progress.md](../progress.md).

### Fill in the Blank (3 points)

1. ______ verifies a user's identity, while ______ determines what actions they're allowed to perform.

2. JWTs are ______ — they carry user information within the token itself, eliminating the need for server-side session storage.

3. The security principle of "never trust, always verify — even for internal requests" is called ______ architecture.

### Multiple Choice (4 points)

4. A JWT has expired but the user's browser still sends it with requests. What should the server do?

   - a) Accept it — the signature is still valid
   - b) Reject it with 401 Unauthorized
   - c) Refresh it automatically
   - d) Accept it but log a warning

5. Your API receives 1,000 login attempts per minute from a single IP address, all with different usernames. This is most likely:

   - a) A popular service with many users behind NAT
   - b) A credential stuffing attack
   - c) Normal traffic during peak hours
   - d) A DDoS attack

6. Which defense is most effective against SQL injection?

   - a) Input length validation
   - b) Parameterized queries / prepared statements
   - c) Web application firewall (WAF)
   - d) HTTPS encryption

7. In a zero trust architecture, two internal microservices communicating within the same VPC should use:

   - a) Plain HTTP — they're already inside the network
   - b) mTLS — verify both client and server certificates
   - c) API keys only
   - d) VPN tunnel

### Short Answer (3 points)

8. Explain why a JWT can't be revoked before its expiry time without additional infrastructure. What infrastructure would you add to support immediate revocation?

9. Your public API serves both anonymous users and authenticated users. Design a rate limiting strategy that limits anonymous users by IP (100/min) and authenticated users by API key (1,000/min). How do you handle a user who is both authenticated AND making requests from a banned IP?

10. A system stores user passwords, credit card numbers, and home addresses. For each, describe the appropriate encryption strategy (at rest, in transit, or both) and any special handling requirements.

<details>
<summary>Answer Key</summary>

1. **Authentication (AuthN)** / **Authorization (AuthZ)**
2. **stateless** (or "self-contained")
3. **zero trust**
4. **b)** — Expired JWTs must be rejected. The expiry time (`exp` claim) is part of the security model. Even though the signature is valid, the token's authorization has expired. The client should request a new token (typically via a refresh token).
5. **b)** — Credential stuffing: using leaked username/password pairs from other breaches to try logging into your service. Many different usernames from one IP is the signature pattern. DDoS (d) would be high-volume requests to any endpoint, not specifically login.
6. **b)** — Parameterized queries separate SQL code from data, making injection impossible. The database engine treats user input as data values, never as SQL code. WAFs (c) can help but are bypassable. Input validation (a) is defense in depth but not sufficient alone. HTTPS (d) protects data in transit, not against injection.
7. **b)** — Zero trust means internal traffic is not trusted. mTLS verifies both sides' identities with certificates, encrypts the connection, and prevents internal MITM attacks. "Inside the VPC" is not a security boundary in zero trust.
8. JWTs are stateless — the server validates them using only the token's contents and signature, without checking any server-side state. There's no "session" to invalidate. To support revocation: add a token blacklist (store revoked token IDs in Redis). On every request, check if the JWT's ID (`jti` claim) is in the blacklist. This adds a server-side lookup (breaking pure statelessness) but enables immediate revocation. Alternative: use short-lived access tokens (5-15 minutes) with long-lived refresh tokens (days). Revoke the refresh token; the access token expires naturally soon after.
9. Apply both limits independently. Anonymous: track by IP, 100 requests/min. Authenticated: track by API key, 1,000 requests/min. If a request is authenticated but from a banned IP: still allow it (the user is identified and authenticated — banning their IP punishes legitimate use behind shared networks). However, if the IP is banned for security reasons (not just rate limiting), reject even authenticated requests and alert the account holder. The key distinction: rate limiting by IP is a coarse control for anonymous abuse. Rate limiting by API key is a fine-grained control for identified users.
10. **Passwords:** Never store in plaintext. Hash with bcrypt/scrypt/argon2 (slow hashing to resist brute force). Encrypt in transit (HTTPS). Don't encrypt at rest — hashing is the correct approach (one-way, not reversible). **Credit card numbers:** Encrypt at rest (AES-256). Encrypt in transit (TLS). Use tokenization if possible (replace card number with a token; let the payment processor handle the real number). PCI DSS compliance required — minimize where card data is stored. **Home addresses:** Encrypt at rest (database-level or field-level encryption). Encrypt in transit (HTTPS). GDPR/privacy implications: provide deletion upon request, limit access to authorized services only, audit access logs.

</details>

---

## Challenge Mission: "The Fortress"

### Scenario

Your company operates a public API serving 10 million users. Recent incidents:
- **Incident 1:** A developer's API key was accidentally committed to a public GitHub repo. Attackers used it to access user data for 6 hours before the key was revoked.
- **Incident 2:** A DDoS attack took the API offline for 45 minutes, costing $200K in lost revenue.
- **Incident 3:** A security researcher found that the `/admin` endpoint was accessible to any authenticated user (no authorization check).

### Your Task

**Part 1: Authentication Redesign**
1. Replace API keys with a more secure authentication system. What do you use?
2. How do you handle key/token rotation?
3. How do you prevent incident 1 from happening again?

**Part 2: Authorization**
1. Design an authorization model that prevents incident 3.
2. How do you enforce it consistently across 15 API endpoints?
3. How do you audit who accessed what?

**Part 3: DDoS Mitigation**
1. Design a multi-layer defense against DDoS.
2. What happens at each layer when attack traffic arrives?
3. How do you distinguish legitimate traffic spikes from attacks?

**Part 4: Rate Limiting**
1. Design rate limits per user and per IP.
2. What rate limiting algorithm do you use?
3. How do you handle rate limiting across multiple API server instances?

### Constraints

- Must support both web clients and server-to-server API consumers
- 99.99% availability target (can't block legitimate users during DDoS)
- Must comply with SOC 2 requirements (audit logging, encryption)

---

## Glossary Terms

Add these to your [glossary](../glossary.md) under Module 3:

- **Authentication (AuthN)** — Verifying identity ("who are you?").
- **Authorization (AuthZ)** — Verifying permissions ("what can you do?").
- **JWT (JSON Web Token)** — Stateless, signed token carrying user claims. Self-contained but can't be revoked before expiry without additional infrastructure.
- **OAuth 2.0** — Delegated authorization framework. Enables "Login with Google" and third-party access.
- **DDoS** — Distributed Denial of Service. Overwhelm a system with traffic.
- **SQL injection** — Malicious SQL in user input. Prevented by parameterized queries.
- **TLS (Transport Layer Security)** — Encryption for data in transit. HTTPS = HTTP + TLS.
- **mTLS (Mutual TLS)** — Both client and server verify certificates. Used in zero trust architectures.
- **Zero trust** — Security model: never trust, always verify. Even internal traffic is authenticated and authorized.
- **Encryption at rest** — Encrypting stored data. Protects against physical theft of storage media.
