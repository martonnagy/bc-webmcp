# MVP feasibility result

## Current decision

**Status: NOT TESTED**

The extension has been implemented and compiled, but it has not been deployed
or exercised in a Business Central browser session. This document must remain
`NOT TESTED` until the manual procedure has produced evidence for H1–H5.

## Environment

| Field | Value |
|---|---|
| Test date | Not tested |
| Business Central version | Not tested |
| Tenant/environment | Not tested |
| Browser and version | Not tested |
| WebMCP configuration | Not tested |
| Agent surface | Not tested |
| Extension version | 0.1.0.0 |

## Hypotheses

| ID | Hypothesis | Status | Evidence |
|---|---|---|---|
| H1 | `document.modelContext` exists in the control-add-in document | NOT TESTED | — |
| H2 | `registerTool()` is permitted in that browsing context | NOT TESTED | — |
| H3 | The browser agent discovers the nested document's tool | NOT TESTED | — |
| H4 | JavaScript can complete a correlated JS-to-AL-to-JS call | NOT TESTED | — |
| H5 | The FactBox record follows the Customer Card record | NOT TESTED | — |

## Test results

| ID | Test | Status | Evidence/notes |
|---|---|---|---|
| T01 | Load Customer Card with FactBox visible | NOT TESTED | — |
| T02 | Detect `document.modelContext` | NOT TESTED | — |
| T03 | Register the tool | NOT TESTED | — |
| T04 | Discover the tool with an agent | NOT TESTED | — |
| T05 | Invoke on the first Customer | NOT TESTED | — |
| T06 | Navigate to a second Customer and invoke again | NOT TESTED | — |
| T07 | Collapse and reopen the FactBox | NOT TESTED | — |
| T08 | Open in an unsupported browser/session | NOT TESTED | — |
| T09 | Reject an unknown tool name | NOT TESTED | — |
| T10 | Close the page during a pending call | NOT TESTED | — |

## Decision criteria

- **GO:** H1–H5 pass in at least one supported challenge browser environment,
  including correct results for two Customers.
- **CONDITIONAL GO:** the core path works but depends on a particular supported
  browser, manual FactBox expansion, or another documented lifecycle condition.
- **NO-GO for the FactBox architecture:** the control-add-in context cannot use
  WebMCP because Business Central owns an unchangeable iframe permission or
  sandbox restriction, or supported agents cannot discover its registered tool.

## Final decision

Not yet assigned. Complete
[the manual feasibility test](manual-feasibility-test.md), link the captured
evidence above, and then replace this section with GO, CONDITIONAL GO, or NO-GO
and a concise rationale.
