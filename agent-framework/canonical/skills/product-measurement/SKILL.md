---
name: product-measurement
description: Define activation, retention, conversion and experiments with explicit measurement and interpretation; analyze real supplied data without installing analytics.
---

# Product Measurement

## Trigger and inputs
Use when defining product success metrics, a measurement plan or interpreting an experiment. Inputs: brief/decision, user value, available real data, privacy constraints, exposure/cohorts and experiment resources. Distinguish measured outcomes, simulations and hypotheses. No data means an unknown outcome.

## Method and output
Use `agent-framework/templates/measurement-plan.md` for definitions and `experiment-report.md` for outcomes. Define value-linked activation, retention and conversion only when applicable, with numerator, denominator, cohort, time window, source, identity/deduplication and exclusions. Specify data quality checks and privacy/minimization/consent/retention needs. Existing aggregate or manual measurement may suffice; recommend instrumentation separately rather than installing an SDK or tracking code.

For an experiment state falsifiable hypothesis, target audience, exposure/allocation, primary metric, guardrails, duration/sample rationale, analysis and stopping/interpretation rules before seeing outcomes. Check novelty, selection bias, instrumentation changes, small samples and confounders. Report uncertainty and practical effect; do not label correlation causal or a weak result a win.

## Verification and stop
A second analyst can reproduce metric definitions and results from the stated data. Every result names the actual source/date/window and limitations; missing data remains UNKNOWN. Saving assigned analysis/specification documents requires execute authorization and a write-capable role contract. The growth-analyst is read-only even in execute mode: return its report in conversation; the coordinator may save it when authorized, invoking technical-writer only when that responsibility is needed. This method grants no write authority and never permits tracking/product code. Stop when the requested plan or reproducible report is complete, or identify the precise data needed to decide.
