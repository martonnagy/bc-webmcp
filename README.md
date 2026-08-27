# BC WebMCP

![BC WebMCP](logo.png)

BC WebMCP exposes safe, structured, page-contextual tools from Microsoft
Dynamics 365 Business Central through the experimental WebMCP browser API.

Version 0.5 adds the WebMCP FactBox to the standard Customer, Vendor, and Item
cards and lists. Card FactBoxes follow the current record. List FactBoxes expose
one read-only operation that follows the page's current filters and sort order.
Every request is sent through Business Central AL so normal record permissions
remain in force.

## Status

The original Customer primary-key MVP has been verified by the project owner.
The 0.5 source and its separate AL test extension compile against Business
Central 28/runtime 17; the complete browser acceptance matrix still needs to be
exercised in a sandbox.

The original [feasibility result](docs/mvp-feasibility-result.md) is retained as
historical evidence rather than rewritten without its original browser details.

## Built-in tools

| Tool | Arguments | Access |
|---|---|---|
| `bc_get_current_record_primary_key` | none | read-only |
| `bc_get_record_info` | none | read-only |
| `bc_get_financial_info` | none | read-only |
| `bc_get_ledger_entries` | optional positive integer `count` | read-only |
| `bc_get_documents` | required `documentKind`, optional positive integer `count` | read-only |
| `bc_set_last_accessed_by_webmcp` | none | writes only the WebMCP timestamp |
| `bc_get_current_list` | optional positive integer `count` | read-only; list pages only |

Every successful card response contains a `context` object with the table
identity, native primary-key position, and structured primary-key fields.
Retrieval responses also report the requested, applied, and returned counts and
whether more records exist. Requests above the configured maximum are capped
and reported rather than rejected.

On the standard Customer, Vendor, and Item lists, `bc_get_current_list` is the
only registered tool. It returns rows in the page's current filter, key, and
sort order. List responses include `totalCount`, `returnedCount`, `isLimited`,
and `hasMore`. When `isLimited` is true, the result is only a partial view and
must not be presented as a complete ranking. Customer rows include sales and
balance facts, vendor rows include purchases and balance facts, and item rows
include inventory, order quantities, price, and cost.

### Document kinds

Customers support sales documents, vendors support purchase documents, and
items support both.

- Unposted sales: `salesQuote`, `salesOrder`, `salesInvoice`,
  `salesCreditMemo`, `salesBlanketOrder`, `salesReturnOrder`.
- Posted sales: `postedSalesInvoice`, `postedSalesCreditMemo`,
  `postedSalesShipment`, `postedSalesReturnReceipt`.
- Unposted purchase: `purchaseQuote`, `purchaseOrder`, `purchaseInvoice`,
  `purchaseCreditMemo`, `purchaseBlanketOrder`, `purchaseReturnOrder`.
- Posted purchase: `postedPurchaseInvoice`, `postedPurchaseCreditMemo`,
  `postedPurchaseReceipt`, `postedPurchaseReturnShipment`.

Customer lookups include both sell-to and bill-to roles. Vendor lookups include
both buy-from and pay-to roles. Duplicate headers are removed and the matched
roles are returned. Item lookup starts from matching item lines but returns the
entire document and identifies the matching line numbers.

## Setup

Open **BC WebMCP Setup** through Tell Me. Setup is per company and is initialized
on install, upgrade, and company creation.

| Setting | Default |
|---|---:|
| Default Ledger Entry Count | 10 |
| Maximum Ledger Entry Count | 100 |
| Default Document Count | 10 |
| Maximum Document Count | 20 |
| Default List Count | 20 |
| Maximum List Count | 100 |

Assign `BC WEBMCP USER` to users of the FactBox and `BC WEBMCP ADMIN` to setup
administrators. These permission sets cover extension-owned objects only. They
do not grant read or write access to Customer, Vendor, Item, ledger, or document
tables.

The timestamp tool sets `Last Accessed by WebMCP` to `CurrentDateTime` using
`Modify(false)`. It does not invoke the base table's `OnModify` trigger, does not
touch other fields, and still requires the user to have permission to modify the
current base record. Read tools never change this timestamp.

## Architecture

```text
Browser agent
  -> dynamically registered document.modelContext tools
  -> JavaScript pending-call map
  -> Business Central control add-in event
  -> generic FactBox record or filtered-list context
  -> internal BC WebMCP Management dispatcher
  -> typed Customer / Vendor / Item record or list provider
  -> JavaScript completion callback
  -> text-wrapped structured JSON result
```

The FactBox is source-table independent. Card pages pass their current
`RecordId`. Supported list pages pass the table ID and `GetView(false)` value so
execution can reapply the current filters and sorting. The public `BC WebMCP
Interface` codeunit exposes record-context integration events for other
extensions. See [Extending BC WebMCP](docs/extending-bc-webmcp.md).

## Build and tests

Compile the production app from the repository root:

```bash
scripts/compile-al.sh --project . --out .output/bc-webmcp.app
```

The separate test app uses the `TEST` preprocessor symbol so its source is not
included in the production package. Build the production app first, place that
package and the standard symbols in `tests/.alpackages`, then compile:

```bash
scripts/compile-al.sh \
  --project tests \
  --out tests/.output/bc-webmcp-tests.app
```

The AL bridge is the preferred validation route when its VS Code session is
available. Package caches, output apps, and generated XLF files are out of
source-control scope.

## Browser notes

Business Central lazy-loads FactBoxes. The FactBox pane must be expanded and BC
WebMCP brought into view before its control add-in can register tools. WebMCP is
experimental, and iframe permission or agent-discovery behaviour can change
independently of this AL extension. The original browser setup and evidence
procedure remains in [Manual feasibility testing](docs/manual-feasibility-test.md).

List ranking follows the page's current order. If the response says
`isLimited: true`, the agent has received only `returnedCount` of `totalCount`
matching records and must disclose that limitation.

## License

MIT. See [LICENSE](LICENSE).
