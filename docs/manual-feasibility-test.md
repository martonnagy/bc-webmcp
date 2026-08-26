# Manual feasibility testing

This procedure verifies the runtime hypotheses that a source build cannot
settle. Do not claim a GO result until the evidence has been captured in
`mvp-feasibility-result.md`.

## Test environment

Record before testing:

- Business Central tenant, environment, application version, and platform
  version without publishing secrets.
- Browser product and exact version.
- WebMCP feature/flag configuration.
- Agent surface used for discovery and invocation.
- Two Customer numbers safe to expose in screenshots.

Install the extension in a sandbox. Open a Customer Card, expand the FactBox
pane, scroll **BC WebMCP** into view, and keep it visible during discovery and
invocation.

## Test cases

### T01 — Load the FactBox

Open a Customer Card with the FactBox visible.

Expected: the diagnostic panel renders and reports the WebMCP feature state.

### T02 — Detect WebMCP

Inspect the control-add-in document and its diagnostic panel.

Expected: `document.modelContext.registerTool` exists. If it does not, capture
the browser setup and exact diagnostic text.

### T03 — Register the tool

Wait for registration to settle.

Expected: the FactBox reports
`Registered: bc_get_current_record_primary_key`. Capture any exception name and
message exactly, especially `NotAllowedError` or `SecurityError`.

### T04 — Discover the tool

Ask the browser agent to list or use tools available from the current page.

Expected: the exact tool name and its empty input schema are discoverable.

### T05 — Invoke on the first customer

Ask: "What is the primary key of the Business Central record I am viewing?"

Expected: the agent invokes the tool and receives table 18, table name Customer,
and the visible Customer number in `primaryKeyFields`.

### T06 — Follow a context change

Navigate to a second Customer Card while keeping the FactBox visible, then ask
the same question.

Expected: the result contains the second Customer number and not the first.

### T07 — Exercise FactBox lifecycle

Collapse the FactBox pane, attempt discovery, reopen it, and bring BC WebMCP
back into view.

Expected: record whether the tool disappears, unregisters, or becomes available
again after the add-in reloads. Visibility-dependent loading is expected.

### T08 — Use an unsupported browser session

Open the Customer Card without WebMCP enabled.

Expected: the FactBox reports that `document.modelContext.registerTool` is
missing instead of failing silently.

### T09 — Reject an unknown tool

From the control-add-in developer context, invoke the AL event with a unique
request ID and an unsupported tool name.

Expected: AL completes it as an error with code `UNKNOWN_TOOL`; it performs no
other operation.

### T10 — Close during a pending call

With developer throttling or a breakpoint, close or navigate away from the page
while a request is pending.

Expected: the promise is rejected with `PAGE_CLOSED` or reaches the ten-second
`TIMEOUT`; no request remains permanently pending.

## Evidence to capture

- Customer Card screenshot with the FactBox diagnostics visible.
- Control-add-in document origin and the generated iframe's `src`, `sandbox`,
  and `allow` attributes.
- Console output for registration failures.
- Agent discovery view showing tool name and schema.
- Tool results for two different Customers.
- Exact browser and Business Central versions.

Do not publish tenant URLs, credentials, access tokens, or sensitive Customer
data.
