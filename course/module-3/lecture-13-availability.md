# Lecture 13: Availability, Resilience & Observability

> Module 3 — "The Distributed Mind" | Lecture 13 of 20

Availability is the other side of the CAP coin. This lecture covers how to keep systems running: availability patterns for redundancy, resilience patterns for graceful failure, and observability to detect problems before users do. This is the most operationally important lecture in the course.

---

## Pre-Reading

**Read these sections from the [System Design Primer](../../deps/system-design-primer/README.md) before starting this lecture:**

- *Availability patterns*
- *Fail-over*
- *Replication*
- *Availability in numbers*

---

## Deep Dive

### What "Nines" Mean

Availability is measured in "nines" — the percentage of time a system is operational:

| Availability | Downtime/Year | Downtime/Month | Downtime/Week |
|-------------|--------------|----------------|---------------|
| 99% (two nines) | 3.65 days | 7.3 hours | 1.68 hours |
| 99.9% (three nines) | 8.77 hours | 43.8 min | 10.1 min |
| 99.95% | 4.38 hours | 21.9 min | 5.04 min |
| 99.99% (four nines) | 52.6 min | 4.38 min | 1.01 min |
| 99.999% (five nines) | 5.26 min | 26.3 sec | 6.05 sec |

**Perspective:** Going from 99.9% to 99.99% reduces annual downtime from 8.77 hours to 52 minutes — but the engineering cost to achieve that improvement is enormous. Each additional nine is roughly 10x harder than the last.

### Calculating Composite Availability

Real systems are composed of multiple components. The overall availability depends on how they're connected.

**Serial (all must work):**
```
A → B → C
Overall = A × B × C
```
If A=99.9%, B=99.9%, C=99.9%:
Overall = 0.999 × 0.999 × 0.999 = 99.7% (not 99.9%!)

Each serial component *reduces* overall availability.

**Parallel (any can work):**
```
A ──┐
    ├──► output
B ──┘
```
Overall = 1 - (1-A) × (1-B)

If A=99.9%, B=99.9%:
Overall = 1 - 0.001 × 0.001 = 99.9999% (six nines!)

Redundancy *dramatically* improves availability. This is why we run multiple instances of everything.

### SLAs and SLOs

**SLA (Service Level Agreement):** A contract with customers specifying minimum availability. Violating an SLA typically triggers financial penalties (credits or refunds).

**SLO (Service Level Objective):** An internal target, usually stricter than the SLA. If your SLA is 99.9%, your SLO might be 99.95% — giving you a buffer before you breach the SLA.

**SLI (Service Level Indicator):** The metric you measure. "P99 latency < 200ms" or "error rate < 0.1%."

**Error budget:** If your SLO is 99.95%, you have 0.05% = 21.9 min/month of allowed downtime. This is your "error budget." Teams can spend this budget on risky deployments, experiments, or planned maintenance. When the budget is exhausted, freeze changes until next month.

---

### Resilience Patterns

Availability patterns handle hardware/network failures. Resilience patterns handle application-level failures — when services are slow, overloaded, or returning errors.

#### Circuit Breaker

Inspired by electrical circuit breakers. When a downstream service starts failing, stop calling it.

```
States:
  CLOSED ──(failures exceed threshold)──► OPEN ──(timeout)──► HALF-OPEN
     ▲                                                           │
     └──────────(success in half-open)────────────────────────────┘
                                                                 │
                                          (failure in half-open) │
                                                    ▼            │
                                                  OPEN ◄─────────┘
```

**CLOSED:** Normal operation. Requests pass through. Count failures.
**OPEN:** Fail fast — reject all requests immediately without calling downstream. Return cached/default response.
**HALF-OPEN:** After a timeout, allow one test request through. If it succeeds, close the circuit. If it fails, re-open.

**Why it matters:** Without a circuit breaker, a failing downstream service causes your service to hang (waiting for timeouts), consuming threads/connections, which makes YOUR service slow, which affects YOUR callers — cascading failure.

#### Retry with Exponential Backoff + Jitter

When a request fails, retry — but not immediately and not all at once.

```
Attempt 1: wait 0ms (immediate)
Attempt 2: wait 1000ms + random(0-1000ms)
Attempt 3: wait 2000ms + random(0-2000ms)
Attempt 4: wait 4000ms + random(0-4000ms)
(give up after max attempts)
```

**Why jitter?** Without jitter, all clients retry at the same intervals. If 1000 clients fail at T=0, they all retry at T=1s, overwhelming the recovering server with 1000 simultaneous requests. Jitter spreads retries over time.

**Without jitter:** 1000 retries at T=1.0s → thundering herd
**With jitter:** retries spread between T=0.5s and T=1.5s → gradual recovery

#### Bulkhead Pattern

Isolate failures to prevent them from affecting the entire system.

```
Without bulkhead:
  Thread Pool (100 threads) shared by ALL downstream calls
  Payment service hangs → all 100 threads stuck → ALL features blocked

With bulkhead:
  Thread Pool A (30 threads): Payment calls
  Thread Pool B (30 threads): Catalog calls
  Thread Pool C (40 threads): User calls
  Payment hangs → only 30 threads stuck → Catalog and User still work
```

Named after ship bulkheads — watertight compartments that prevent a hull breach from sinking the entire ship.

#### Timeout Strategies

Every external call needs a timeout. Two types:

**Connect timeout:** How long to wait for the TCP connection. Usually 1-5 seconds. If a service is down, you know quickly.

**Read timeout:** How long to wait for the response after connecting. Depends on the expected operation time. A fast lookup might timeout at 500ms; a report generation might timeout at 30s.

**Rule of thumb:** Set timeouts based on the P99 latency of the downstream service. If P99 is 200ms, set the read timeout to 500ms-1s. If it takes longer, something is wrong.

#### Saga Pattern

Distributed transactions across microservices without two-phase commit (2PC).

```
Order Saga:
  1. Create Order (Order Service)     → success → continue
  2. Reserve Inventory (Inventory)    → success → continue
  3. Charge Payment (Payment)         → FAILS
  4. Compensating actions:
     - Cancel Inventory Reservation (Inventory)
     - Cancel Order (Order Service)
```

Each step has a compensating action. If any step fails, execute compensating actions for all completed steps in reverse order.

**Choreography:** Each service publishes events; the next service reacts. Decoupled but hard to track.
**Orchestration:** A central coordinator (saga orchestrator) directs each step. Easier to reason about, single point of coordination.

#### Graceful Degradation

When the system is under stress, serve reduced functionality instead of failing completely.

| Situation | Degraded Response |
|-----------|------------------|
| Recommendation service is down | Show "Popular items" instead of personalized recommendations |
| Image service is slow | Show placeholder images; load real images when available |
| Search is overloaded | Return cached results from 5 minutes ago |
| Database is at capacity | Serve read-only mode — disable writes temporarily |

**The key principle:** A degraded experience is always better than an error page.

---

### Monitoring & Observability

You can't maintain availability without observing it. Observability is the ability to understand your system's internal state from its external outputs.

#### The Three Pillars

**1. Metrics** — Numerical measurements over time
- Request rate (QPS)
- Error rate (5xx responses / total)
- Latency percentiles (P50, P95, P99)
- Saturation (CPU%, memory%, disk%, queue depth)
- Business metrics (orders/minute, signups/day)

**2. Logs** — Discrete events with context
- Structured logs (JSON) are searchable; unstructured logs are not
- Include: timestamp, request_id, user_id, service_name, log level, message
- Don't log sensitive data (passwords, tokens, PII)

**3. Traces** — The path of a request across services
- Distributed tracing: follow a single request through 10 microservices
- Each service adds a span (start time, end time, metadata) to the trace
- Tools: Jaeger, Zipkin, AWS X-Ray, Datadog APT

#### The RED Method (for request-driven services)

- **R**ate — Requests per second
- **E**rrors — Failed requests per second
- **D**uration — Latency distribution (P50, P95, P99)

#### The USE Method (for resources: CPU, memory, disk, network)

- **U**tilization — Percentage of capacity in use
- **S**aturation — Queue depth (work waiting to be processed)
- **E**rrors — Error count

#### Alerting

**Alert on symptoms, not causes.** Alert on "error rate > 1%" (symptom), not "CPU > 90%" (cause). High CPU might be fine if response times are normal.

**Alert fatigue:** Too many alerts → team ignores them → real incidents are missed. Every alert should be actionable — if the on-call engineer can't do anything about it, it shouldn't page them.

---

## Discussion Prompts

1. **Your system has 5 services in series, each with 99.9% availability. What's the composite availability?** If you add a redundant instance for each service (parallel), what's the new availability? How many nines did you gain?

2. **Your payment service circuit breaker trips (opens). Users can't checkout. Is this good or bad?** What's the alternative without a circuit breaker? Design the degraded experience.

3. **Your monitoring shows P50 latency = 50ms, P99 latency = 2000ms. The average is 120ms. Which metric best represents user experience?** Why is the P99 more important than the average for system design?

---

## Field Ops: Server Survival

In the game, observe:
- **Service health bars** = observability metrics. When a health bar drops, that's saturation.
- **Auto-repair** = a form of self-healing / circuit breaker. The service recovers after a cooldown.
- **The "Active Event Bar"** = alerting. Events notify you of problems (DDoS, traffic spike) before they become fatal.

Play Survival mode and deliberately let one service die. Watch how it cascades to other services. This is why bulkheads and circuit breakers exist — to prevent exactly this cascade.

---

## Knowledge Check

Record your score in [progress.md](../progress.md).

### Fill in the Blank (3 points)

1. If a system has 99.99% availability, its annual downtime is approximately ______ minutes.

2. The resilience pattern that stops calling a failing downstream service and returns a fallback response is called a ______.

3. The three pillars of observability are metrics, ______, and traces.

### Multiple Choice (4 points)

4. Two services are in series, each with 99.9% availability. A parallel redundant instance is added for Service B. What's the approximate system availability?

   - a) 99.8%
   - b) 99.9%
   - c) 99.89%
   - d) 99.999%

5. Your retry logic has no jitter. 500 clients fail at the same time and retry after exactly 1 second. What happens?

   - a) The server recovers because retries are spaced out
   - b) 500 simultaneous retries hit the server, potentially causing another failure
   - c) The circuit breaker prevents all retries
   - d) Clients automatically add jitter

6. Which alerting approach best avoids alert fatigue?

   - a) Alert on every metric that exceeds its threshold
   - b) Alert on symptoms (error rate, latency) rather than causes (CPU, memory)
   - c) Set extremely sensitive thresholds to catch problems early
   - d) Alert on all causes and let the on-call engineer determine relevance

7. A distributed transaction spans 3 services. Service C fails after Services A and B have committed. Using the Saga pattern, what happens?

   - a) Services A and B automatically roll back their transactions
   - b) Compensating actions are executed for A and B in reverse order
   - c) The entire system retries until Service C succeeds
   - d) The transaction is left in a partial state

### Short Answer (3 points)

8. Calculate the composite availability of this system: Load Balancer (99.99%) → 2 App Servers in parallel (each 99.9%) → Database Primary (99.95%) with 1 replica (99.95%) in parallel. Show your work.

9. A microservice makes HTTP calls to 3 downstream services. Currently, there are no timeouts configured. Describe a realistic failure scenario where this causes a cascading outage, and explain which resilience patterns would prevent it.

10. Your SLA guarantees 99.95% availability. Last month, you had 25 minutes of downtime. Did you breach the SLA? How much error budget do you have remaining for the month?

<details>
<summary>Answer Key</summary>

1. **52.6 minutes** (or approximately 53 minutes)
2. **circuit breaker**
3. **logs**
4. **c) 99.89%** — Service A: 99.9%. Service B parallel: 1-(1-0.999)² = 1-0.000001 = 99.9999%. System = 0.999 × 0.999999 ≈ 99.899% ≈ 99.9%. (Accept 99.89% or 99.9% — the parallel Service B is effectively 100%.)
5. **b)** — Without jitter, all 500 clients retry at exactly T+1s. The server gets 500 simultaneous requests — which is likely the same load that caused the original failure, creating a retry storm. This is why jitter is essential.
6. **b)** — Alerting on symptoms (error rate, latency) is more actionable and produces fewer false positives. CPU at 90% might be normal for that workload; error rate at 5% is always a problem. Symptom-based alerting reduces noise while catching real issues.
7. **b)** — The Saga pattern uses compensating actions. Service A committed → run A's compensating action (e.g., cancel order). Service B committed → run B's compensating action (e.g., release inventory). This brings the system back to a consistent state. Note: compensating actions must be idempotent because they might need to run more than once.
8. LB: 99.99%. App Servers parallel: 1-(1-0.999)² = 1-0.000001 = 99.9999%. DB parallel: 1-(1-0.9995)² = 1-(0.0005)² = 1-0.00000025 = 99.999975%. System = 0.9999 × 0.999999 × 0.99999975 ≈ 99.989% ≈ **99.99%**. The LB is the bottleneck at 99.99%. Adding redundancy to app servers and DB brought them above 99.99%, so the LB's 99.99% limits the system.
9. Scenario: Service A calls Service B, which calls Service C. Service C's database is overloaded and responding slowly (30-second responses instead of 200ms). Without timeouts: Service B's threads hang waiting 30 seconds for Service C. All Service B threads become occupied. Service A's threads hang waiting for Service B. All Service A threads become occupied. The web server's threads hang waiting for Service A. Users see the entire application frozen. Fix: (1) **Timeouts** on all HTTP calls (500ms read timeout for Service C). (2) **Circuit breaker** — after 5 failures from Service C, stop calling it and return a fallback. (3) **Bulkhead** — dedicate separate thread pools for each downstream, so Service C's slowness can't consume all threads.
10. SLA: 99.95% = 0.05% allowed downtime per month. Monthly minutes: 30 × 24 × 60 = 43,200 minutes. Allowed downtime: 43,200 × 0.0005 = **21.6 minutes**. Actual downtime: 25 minutes. **Yes, the SLA was breached** by 3.4 minutes. Error budget remaining: 21.6 - 25 = **-3.4 minutes** (overdrawn).

</details>

---

## Challenge Mission: "The Uptime Contract"

### Scenario

You're designing a payments API with an SLA of **99.99% availability** (52.6 minutes of downtime per year).

**Current architecture:**
```
              ┌──► API Server 1 (99.9%)
Client → LB ─┼──► API Server 2 (99.9%)
 (99.99%)     └──► API Server 3 (99.9%)

API Servers → Primary DB (99.95%) ──replication──► Replica DB (99.95%)
API Servers → Redis Cache (99.9%)
API Servers → Payment Gateway (external, 99.95%)
```

### Your Task

**Part 1: Calculate composite availability.** Can the current architecture meet 99.99%?

**Part 2: Identify the weakest links.** Which components drag availability below 99.99%?

**Part 3: Add resilience patterns.** For each weakness:
- What pattern (circuit breaker, retry, bulkhead, etc.) do you add?
- How does it improve availability?

**Part 4: Design the monitoring.** What metrics, alerts, and dashboards would you build? Specify thresholds for alerting.

**Part 5: Define the error budget.** With 99.99% SLA, how many minutes per month can you afford? How would you spend this budget (deployments, experiments, maintenance)?

---

## Glossary Terms

Add these to your [glossary](../glossary.md) under Module 3:

- **Availability nines** — Measurement of uptime. 99.9% = three nines (8.77 hrs downtime/year). Each additional nine is ~10x harder.
- **SLA / SLO / SLI** — Agreement (contractual), Objective (internal target), Indicator (the metric). SLO is stricter than SLA.
- **Error budget** — Allowed downtime before SLA breach. Can be "spent" on risky changes.
- **Circuit breaker** — Stops calling a failing service. States: closed (normal), open (fail fast), half-open (testing recovery).
- **Exponential backoff + jitter** — Retry strategy with increasing delays and randomness to prevent thundering herds.
- **Bulkhead** — Isolates failure domains (e.g., separate thread pools per downstream service) to prevent cascade.
- **Saga pattern** — Manages distributed transactions through compensating actions instead of 2PC.
- **Graceful degradation** — Serving reduced functionality instead of failing completely during stress.
- **RED method** — Rate, Errors, Duration — key metrics for request-driven services.
- **USE method** — Utilization, Saturation, Errors — key metrics for resources.
- **Distributed tracing** — Following a request across multiple services. Each service adds a span. Tools: Jaeger, Zipkin.
