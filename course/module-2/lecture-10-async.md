# Lecture 10: Asynchronism — Queues & Back Pressure

> Module 2 — "The Data Fortress" | Lecture 10 of 20

Not every request needs an immediate response. When a user uploads a photo, they don't need to wait for 5 thumbnail sizes to be generated. When an order is placed, the confirmation email can be sent a few seconds later. Asynchronous processing decouples work from the request cycle, making systems faster, more resilient, and able to handle traffic spikes gracefully.

---

## Pre-Reading

**Read these sections from the [System Design Primer](../../deps/system-design-primer/README.md) before starting this lecture:**

- *Asynchronism*
- *Message queues*
- *Task queues*
- *Back pressure*

---

## Deep Dive

### Why Async Matters

**Synchronous:** The client waits for every step to complete.
```
Upload photo → generate thumbnails (30s) → update DB → send notification → return "done"
Total time: ~32 seconds. User stares at a spinner.
```

**Asynchronous:** Return immediately, do the work in the background.
```
Upload photo → save to storage → enqueue thumbnail job → return "uploaded!"  (200ms)

Background: thumbnail worker picks up job → generates 5 sizes → updates DB → sends notification
```

The user gets a response in 200ms instead of 32 seconds. The work still happens, just not inline with the request.

### Message Queues

A message queue is a buffer between producers (who create work) and consumers (who process it).

```
Producer ──► [Queue: msg1, msg2, msg3] ──► Consumer
```

**Core concepts:**
- **Producer** — Sends messages to the queue
- **Consumer** — Reads messages from the queue and processes them
- **Message** — A unit of work (JSON payload, job description)
- **Acknowledgment (ACK)** — Consumer tells the queue "I've processed this message." The queue removes it.
- **Visibility timeout** — After a consumer picks up a message, it's invisible to other consumers for N seconds. If the consumer doesn't ACK in time, the message becomes visible again for retry.

#### Message Queue Technologies

| Technology | Architecture | Best For | Key Feature |
|-----------|-------------|----------|-------------|
| **RabbitMQ** | Broker-based, AMQP | Task distribution, routing | Flexible routing (direct, topic, fanout) |
| **Amazon SQS** | Managed, pull-based | Simple job queues in AWS | Zero ops, auto-scaling |
| **Apache Kafka** | Distributed log | Event streaming, high throughput | Persistent, replayable, ordered within partitions |
| **Redis Streams** | In-memory, append-only log | Lightweight streaming | Fast, built into Redis |

#### Kafka Deep Dive (Most Important for System Design)

Kafka is not just a message queue — it's a distributed commit log. Messages are persistent and replayable.

```
Producer → Topic (partitioned) → Consumer Group

Topic: "user-events"
  Partition 0: [msg1, msg4, msg7, ...]
  Partition 1: [msg2, msg5, msg8, ...]
  Partition 2: [msg3, msg6, msg9, ...]

Consumer Group A:
  Consumer 1 ← reads Partition 0
  Consumer 2 ← reads Partition 1
  Consumer 3 ← reads Partition 2
```

Key properties:
- **Ordering** — Guaranteed within a partition, not across partitions
- **Retention** — Messages are kept for a configurable period (days/weeks), not deleted after consumption
- **Replay** — Consumers can re-read old messages (useful for reprocessing)
- **Throughput** — Millions of messages per second across partitions
- **Consumer groups** — Multiple independent consumers can read the same topic

### Task Queues

A specialized message queue for background job processing.

```
Web Request → Create Job → Task Queue → Worker picks up → Processes → Done
```

| Technology | Language | Common Use |
|-----------|----------|-----------|
| **Celery** | Python | Background tasks in Django/Flask apps |
| **Sidekiq** | Ruby | Background jobs in Rails apps |
| **Bull** | Node.js | Job processing in Node apps |

Task queues add features on top of message queues: retries, scheduling, priority levels, rate limiting, and dead letter handling.

### Event-Driven Architecture

Instead of services calling each other directly (request/response), they communicate through events.

**Request/Response (synchronous):**
```
Order Service → calls → Inventory Service → calls → Notification Service
(coupled, cascade failure risk)
```

**Event-Driven (asynchronous):**
```
Order Service → publishes "OrderCreated" event → Message Bus
  ├── Inventory Service subscribes → deducts stock
  ├── Notification Service subscribes → sends email
  ├── Analytics Service subscribes → records metrics
  └── (any future service can subscribe without changing Order Service)
```

| Pros | Cons |
|------|------|
| Services are decoupled — no direct dependencies | Harder to trace a request across services |
| Adding new consumers requires no change to producers | Eventual consistency (events take time to propagate) |
| Resilient — if a consumer is down, events queue up | Debugging is harder (async, distributed) |
| Natural scaling — add more consumers for more throughput | Event ordering can be tricky |

### Back Pressure

What happens when producers send messages faster than consumers can process them?

```
Producer: 10,000 msgs/sec → Queue → Consumer: 5,000 msgs/sec
                              ↑
                         Queue grows unboundedly!
```

Without back pressure, the queue grows until it runs out of memory or disk, and the system crashes.

**Back pressure strategies:**

**1. Drop messages**
- When the queue is full, reject new messages
- The producer gets an error and can decide what to do (retry, log, alert)
- Acceptable for non-critical data (metrics, analytics)

**2. Slow down producers**
- Return errors or use rate limiting when the queue is near capacity
- The producer backs off (ideally with exponential backoff + jitter)
- Preserves the queue but degrades the producer's experience

**3. Scale consumers**
- Auto-scale the number of consumers based on queue depth
- If queue depth > threshold → add consumers
- If queue depth drops → remove consumers
- Most scalable solution, but has a ramp-up delay

**4. Bounded queue with blocking**
- Queue has a maximum size
- When full, producers block until space is available
- Simple, but can cascade — if the producer is a web server, it blocks user requests

**In practice:** Most systems combine strategies — auto-scale consumers as the first line of defense, rate-limit producers as the second, and drop non-critical messages as the last resort.

### Delivery Guarantees

How many times will a message be processed?

| Guarantee | Description | Risk | Use Case |
|-----------|-------------|------|----------|
| **At-most-once** | Message may be lost, never reprocessed | Lost messages | Metrics, logs (losing a few is OK) |
| **At-least-once** | Message is guaranteed delivered, may be duplicated | Duplicate processing | Most use cases (with idempotent consumers) |
| **Exactly-once** | Message is delivered and processed exactly once | Most complex to implement | Financial transactions, inventory |

**The dirty secret:** True exactly-once is extremely hard in distributed systems. Most "exactly-once" systems are actually "at-least-once with deduplication" — the consumer checks if it's already processed the message (using an idempotency key) and skips duplicates.

**Idempotent consumers:** Design consumers so that processing the same message twice has the same effect as processing it once.

```python
# NOT idempotent: processes twice → charges twice
def process_payment(order_id, amount):
    charge_credit_card(amount)

# Idempotent: processes twice → charges once
def process_payment(order_id, amount):
    if already_processed(order_id):
        return  # skip duplicate
    charge_credit_card(amount)
    mark_as_processed(order_id)
```

### Dead Letter Queues and Poison Messages

**Poison message:** A message that causes the consumer to crash or fail every time it tries to process it (e.g., malformed data, invalid reference).

Without handling: the message is retried forever, blocking the queue.

**Dead Letter Queue (DLQ):** After N failed attempts, move the message to a separate queue for manual inspection.

```
Main Queue → Consumer fails 3 times → Dead Letter Queue → Alert ops team
```

DLQs prevent poison messages from blocking the entire system and give you a way to investigate and reprocess failed messages.

---

## Discussion Prompts

1. **Your notification service sends emails, SMS, and push notifications. Currently it's called synchronously from the order service — if the email provider is slow, order creation is slow. Redesign this with async processing.** What happens if the SMS provider is down for 2 hours? Do customers miss their notifications?

2. **A Kafka topic has 3 partitions and you have 5 consumers. What happens?** What if you have 2 consumers? How do you decide the right number of partitions for a topic?

3. **You process payments asynchronously via a queue. A customer places an order, and 10 seconds later the payment fails (insufficient funds). The customer already sees "Order Confirmed" on their screen.** How do you handle this? What's the user experience?

---

## Field Ops: Server Survival

Open [Server Survival](../../deps/server-survival/index.html) and play **Survival mode**.

**Goal:** Survive a DDoS spike without losing >5% reputation.

Focus on:
- Place a **Queue** service to buffer incoming traffic during spikes
- Watch what happens during a traffic burst with and without the Queue
- Without Queue: traffic burst → Compute overwhelmed → requests dropped → reputation loss
- With Queue: traffic burst → Queue absorbs burst → Compute processes at its own pace → fewer dropped requests

The Queue is literally back pressure in action — it absorbs the difference between arrival rate and processing rate.

Record your score in [progress.md](../progress.md).

---

## Knowledge Check

Record your score in [progress.md](../progress.md).

### Fill in the Blank (3 points)

1. A message that causes the consumer to fail every time it's processed is called a ______ message, and is typically moved to a ______ queue after N failed attempts.

2. The delivery guarantee where a message may be processed more than once (but never lost) is called ______ delivery.

3. In Kafka, message ordering is guaranteed within a single ______ but not across multiple ones in the same topic.

### Multiple Choice (4 points)

4. A user uploads a photo. Your system needs to: (1) save the photo to S3, (2) generate 5 thumbnail sizes, (3) update the database with thumbnail URLs, (4) send a push notification. Which operations should be synchronous (in the request) and which async?

   - a) All synchronous — the user waits for everything
   - b) Save to S3 synchronous; everything else async
   - c) All async — return immediately before saving
   - d) Save to S3 and generate thumbnails synchronous; the rest async

5. Your message queue has 100,000 messages backed up. Consumers process 1,000 messages/second. A new producer starts sending 2,000 messages/second. What's your best immediate response?

   - a) Add more producers to clear the backlog faster
   - b) Auto-scale the number of consumers
   - c) Drop all messages in the queue and start fresh
   - d) Increase the queue size limit

6. Which delivery guarantee requires consumers to be idempotent to work correctly?

   - a) At-most-once
   - b) At-least-once
   - c) Exactly-once
   - d) All of the above

7. A Kafka topic has 6 partitions. You deploy 6 consumers in the same consumer group. One consumer crashes. What happens?

   - a) Messages on the crashed consumer's partition are lost
   - b) The partition is reassigned to one of the remaining 5 consumers
   - c) All consumers stop until the crashed one recovers
   - d) A new consumer is automatically created

### Short Answer (3 points)

8. Explain the difference between a message queue (like SQS) and a streaming platform (like Kafka). When would you choose one over the other?

9. Design an idempotent payment processor. A message `{order_id: 42, amount: $99.99}` arrives in the queue. How do you ensure it's charged exactly once even if the message is delivered 3 times?

10. Your e-commerce site processes 10,000 orders/hour normally. On Black Friday, it spikes to 100,000 orders/hour. Your payment processor can only handle 15,000/hour. Design an async architecture that handles this without losing orders or charging customers late.

<details>
<summary>Answer Key</summary>

1. **poison** / **dead letter** (DLQ)
2. **at-least-once**
3. **partition**
4. **b)** — Save to S3 must be synchronous because the user needs confirmation that their photo is safely stored. Thumbnail generation (30+ seconds), database updates, and notifications can all happen asynchronously — the user doesn't need to wait for thumbnails to finish. Return "uploaded!" after S3 save, then enqueue the rest.
5. **b)** — Auto-scaling consumers is the correct response. With 1,000 consumed/sec and 2,000 produced/sec, the queue grows by 1,000/sec. Adding consumers increases processing rate. Adding producers (a) adds more messages, making it worse. Dropping messages (c) loses data. Increasing queue size (d) delays the problem but doesn't solve it.
6. **b)** — At-least-once delivery means a message may be delivered multiple times. Consumers must be idempotent to handle duplicates correctly. At-most-once (a) doesn't deliver duplicates, so idempotency isn't needed. Exactly-once (c) handles deduplication at the infrastructure level.
7. **b)** — Kafka performs "rebalancing" — the crashed consumer's partition is reassigned to one of the remaining consumers. That consumer now reads from 2 partitions. No messages are lost (they're persisted in Kafka). When the crashed consumer comes back, another rebalance distributes partitions evenly again.
8. A message queue (SQS) is designed for task distribution: a message is consumed by one consumer, then deleted. It's fire-and-forget — once processed, the message is gone. A streaming platform (Kafka) is a persistent log: messages are retained for a configurable period and can be read by multiple consumer groups independently. Consumers can replay messages from any point. Choose a message queue for: simple job processing, one-time tasks (send email, generate thumbnail). Choose Kafka for: event sourcing, multiple consumers needing the same events, audit logs, high-throughput data pipelines, or when you need to replay events.
9. Implementation: (1) Consumer receives `{order_id: 42, amount: $99.99}`. (2) Check a `processed_payments` table: `SELECT 1 FROM processed_payments WHERE order_id = 42`. (3) If exists → skip (already processed). (4) If not exists → within a transaction: charge the credit card, INSERT into `processed_payments(order_id, amount, processed_at)`, ACK the message. (5) If the charge succeeds but the INSERT fails, the transaction rolls back, the message is retried, and step 2 catches it. The `order_id` in `processed_payments` is the idempotency key.
10. Architecture: (1) Orders go into a Kafka topic (or SQS queue) immediately — this absorbs the spike. (2) Payment workers consume from the queue at 15,000/hour (the processor's limit). (3) During the spike: 100K orders/hour in, 15K processed/hour → queue grows by 85K/hour. (4) After the spike (back to 10K/hour): 10K in, 15K out → queue drains at 5K/hour. (5) The 85K backlogged orders are processed over ~17 hours. (6) User experience: order is confirmed immediately ("Order received"), payment is processed asynchronously. If payment fails, send a notification asking to update payment method. (7) Key: the queue must be durable (persist to disk) so no orders are lost.

</details>

---

## Challenge Mission: "The Queue Commander"

### Scenario

You're building an image processing service. Users upload photos, and your app generates 5 thumbnail sizes for each (small, medium, large, hero, square).

**Numbers:**
- Peak: 50,000 uploads per hour (14 per second)
- Each thumbnail takes 2 seconds to generate on a single CPU core
- 5 thumbnails per upload = 10 seconds of CPU per upload
- Servers have 4 CPU cores each

### Your Task

**Part 1 — Estimation**

1. At peak, how many CPU-seconds of thumbnail work per hour?
2. How many 4-core servers do you need to keep up with peak load? (Include 20% headroom)
3. If a message sits in the queue for >5 minutes, users start complaining. What's the maximum acceptable queue depth?

**Part 2 — Pipeline Design**

Design the async pipeline:
1. What queue technology would you use? Why?
2. What does the message payload look like?
3. How many consumers (worker processes) per server?
4. Should each consumer generate all 5 thumbnails, or should each thumbnail size be a separate message?

**Part 3 — Failure Handling**

1. A worker crashes mid-generation (3 of 5 thumbnails done). What happens to the other 2?
2. A user uploads a corrupt file that crashes the thumbnail generator. How do you prevent it from blocking the queue?
3. The storage service (S3) is temporarily unavailable. Thumbnails generate but can't be saved. What's your retry strategy?

**Part 4 — Back Pressure**

1. A viral event causes uploads to spike to 200,000/hour (4x peak). Your workers can only handle 50,000/hour. What's your back pressure strategy?
2. How long will the queue take to drain after the spike subsides?
3. At what queue depth do you alert the on-call engineer?

### Constraints

- Users must see at least the "small" thumbnail within 2 minutes of upload
- No upload should ever be lost, even during worker crashes
- Budget: maximum 20 servers for thumbnail processing

---

## Supplementary Reading

**[How Uber Scales Their Real-Time Market Platform](http://highscalability.com/blog/2015/9/14/how-uber-scales-their-real-time-market-platform.html)**

Note how Uber uses message queues and async processing for ride matching, dispatch, and payment. The real-time constraint adds complexity — a ride request can't sit in a queue for 5 minutes.

---

## Glossary Terms

Add these to your [glossary](../glossary.md) under Module 2:

- **Message queue** — A buffer between producers and consumers that enables async processing. Examples: SQS, RabbitMQ.
- **Kafka** — Distributed streaming platform. Persistent, replayable, high-throughput. Messages organized by topics and partitions.
- **Producer** — Service that sends messages to a queue.
- **Consumer** — Service that reads and processes messages from a queue.
- **Back pressure** — Mechanism to prevent producers from overwhelming consumers. Strategies: drop, slow down, scale consumers.
- **Dead letter queue (DLQ)** — Queue for messages that repeatedly fail processing. Prevents poison messages from blocking the main queue.
- **Idempotent** — An operation that produces the same result whether executed once or multiple times.
- **At-least-once delivery** — Guarantees message is delivered but may be duplicated. Requires idempotent consumers.
- **Exactly-once delivery** — Guarantees message is processed exactly once. Usually implemented as at-least-once + deduplication.
- **Event-driven architecture** — Services communicate by publishing and subscribing to events rather than direct calls.
