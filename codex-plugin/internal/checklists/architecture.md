# Architecture Checklist

Three readers, one standard. The planner works it before code exists, the plan
reviewer checks that the plan answered it, and an audit works it against
structure that already shipped.

The audit reading is the one that needs stating: in an audit nothing here was
proposed by this Run, so the five questions below are asked of what exists, and
an unanswerable question is a finding under the `complexity` lens rather than a
blocker in a plan. Structure that predates the audit and works is not a defect
because it would not be chosen today; it becomes a finding when the cost is real
and someone is paying it.

The rule it all reduces to: **use the simplest structure that still preserves the
business rules, security, testability, and the evolution the specification
actually asks for.** Not the simplest imaginable — the simplest that holds.

This exists because a plan is where overengineering is cheap to prevent and
expensive to undo. A layer added here becomes twenty files, a review round, and a
refactor nobody scheduled.

## Five questions before any new layer, pattern, or abstraction

Answer them in the plan, in writing, for each one:

1. What concrete problem does it solve?
2. Does that problem exist **today**, in this specification — not in a plausible
   future version of it?
3. Does it reduce total complexity, or move complexity somewhere less visible?
4. Can someone who did not write it maintain it?
5. Is there a simpler alternative, and why is it not enough?

No concrete answer to 1 and 2 means it does not go in the plan. "We will need it
later" is question 2 answered no.

## Structure levels

Take the lowest one that holds, and say in the plan which one you took.

| Level | When | Shape |
|-------|------|-------|
| Simple | CRUD, internal APIs, most features | controllers, services, repositories, models, DTOs, validators |
| Modular | Real business rules with clear module seams | the same, grouped per module |
| Domain-heavy | Dense invariants, several bounded contexts, long-running processes, a domain worth protecting from an integration | Justified in the plan, per the five questions, or not at all |

The repository's existing structure outranks this table. A plan that introduces a
level the repository does not already use is making an architectural change, and
it says so explicitly rather than arriving as a side effect of a feature.

## Needs an explicit justification, or does not go in

Each of these is legitimate somewhere and wrong by default. Naming the problem it
solves is the price of admission.

- Full DDD, hexagonal, many-layer Clean Architecture, CQRS, event sourcing,
  hand-rolled unit of work, specification objects, mediators everywhere.
- Microservices for a small domain. A modular monolith is usually cheaper and
  safer, and it can be split later by the people who know where the seam is.
- Messaging for a flow that is synchronous and does not need to survive a
  restart.
- An interface, factory, or adapter with one implementation and no planned
  second one. One repository class is enough.
- Pass-through layers: a controller calling a use case calling a service calling
  a manager calling a repository, each adding nothing.
- A general mechanism for a specific requirement. "Send an email after signup"
  does not become a plugin-based automation engine.

## Signals the plan is already too big

If the plan shows these, cut before dispatching it:

- Dozens of files for one feature.
- Classes with one method whose body calls another class.
- More structure than business logic.
- CRUD carrying aggregates and domain events.
- A small change that has to touch every layer.
- Services always deployed together but separated anyway.
- A structure chosen before the problem was understood.

## What the plan states about risk

Beyond the per-task fields `planning.md` requires, the plan names the risks that
decide whether the structure is sufficient: volume, concurrency, authorization,
partial failure, backward compatibility, and observability. A risk named here
becomes a task or an accepted risk in the specification. One that is not named is
one the reviewer will raise later, against code.

## Depth

`references/architecture-review-guide.md` for SOLID, coupling and cohesion,
dependency direction, and the anti-patterns in detail.
`references/code-quality-universal.md` for reuse audits, parameter sprawl, leaky
abstractions, and redundant state. Load one, when a decision actually turns on
it.
