# BC WebMCP

![BC WebMCP](logo.png)

BC WebMCP is a source-level feasibility MVP for exposing safe, structured,
page-contextual tools from Microsoft Dynamics 365 Business Central through the
experimental WebMCP browser API.

The extension adds a FactBox to the standard Customer Card and registers one
read-only tool:

```text
bc_get_current_record_primary_key
```

When invoked, the tool calls AL through a Business Central control add-in and
returns the primary key of the Customer currently displayed on the card.

## Status

The source compiles against Business Central 28/runtime 17. It has **not** been
deployed or tested for WebMCP registration, nested-frame discovery, or live
agent invocation. See [MVP feasibility result](docs/mvp-feasibility-result.md)
for the evidence checklist and current `NOT TESTED` status.

## Architecture

```text
Browser agent
  -> document.modelContext.registerTool()
  -> JavaScript pending-call map
  -> Microsoft.Dynamics.NAV.InvokeExtensibilityMethod()
  -> Customer-bound CardPart AL trigger
  -> RecordRef/KeyRef/FieldRef serializer
  -> AL calls CompleteToolCall()
  -> JavaScript resolves the WebMCP result
```

The tool returns text content containing JSON with this logical shape:

```json
{
  "application": "Microsoft Dynamics 365 Business Central",
  "tableId": 18,
  "tableName": "Customer",
  "primaryKeyPosition": "No.='10000'",
  "primaryKeyFields": [
    {
      "fieldNo": 1,
      "fieldName": "No.",
      "value": "10000"
    }
  ]
}
```

`primaryKeyPosition` uses Business Central's native `RecordRef.GetPosition`
format; its exact punctuation can vary. `primaryKeyFields` is the structured
representation consumers should use.

## Prerequisites

- Business Central online sandbox compatible with application 28/runtime 17.
- Visual Studio Code with the AL Language extension, or a local AL 17 compiler.
- Microsoft application symbols in the project's `.alpackages` directory.
- A company containing at least two Customer records for later live testing.
- A WebMCP-capable browser or ChatGPT browser surface for later feasibility
  testing.

## Configure a sandbox

Copy the tenant-neutral example and replace both placeholders locally:

```bash
cp .vscode/launch.example.json .vscode/launch.json
```

`.vscode/launch.json` is ignored so tenant and environment identifiers are not
committed. In VS Code, run **AL: Download Symbols** to populate `.alpackages`.

## Build

From the repository root:

```bash
scripts/compile-al.sh
```

The output is written to `.output/bc-webmcp.app`. The script searches installed
AL Language extension directories for `elc` or `alc`. Override discovery when
needed:

```bash
scripts/compile-al.sh \
  --compiler /absolute/path/to/alc \
  --packages /absolute/path/to/.alpackages
```

Package caches and compiled `.app` files are ignored and must not be committed.

## Install

Use either of these sandbox-only routes:

1. In VS Code, run the `BC WebMCP Sandbox` launch configuration to publish the
   development extension.
2. Compile the app, open **Extension Management** in the sandbox, and upload
   `.output/bc-webmcp.app`.

Open the Customer List and then a Customer Card after installation. Expand the
FactBox pane and make sure **BC WebMCP** is visible. Business Central lazy-loads
FactBoxes, so WebMCP registration cannot occur while the pane is collapsed or
the FactBox has not been brought into view.

Follow [Manual feasibility testing](docs/manual-feasibility-test.md) before
declaring the architecture GO, CONDITIONAL GO, or NO-GO.

## Scope and security

- Exactly one tool with no input fields.
- Current Customer record only.
- Read-only; no create, modify, delete, posting, or external network operation.
- Unknown tool names are rejected in AL.
- Pending requests are correlated by UUID, time out after ten seconds, and are
  rejected when the add-in document closes.
- Missing WebMCP support and registration exceptions remain visible in the
  FactBox diagnostics.

The detailed design rationale and post-MVP ideas remain in the original
[project handover](bc_webmcp_project_handover.md).

## License

MIT. See [LICENSE](LICENSE).
