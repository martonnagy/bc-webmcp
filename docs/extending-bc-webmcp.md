# Extending BC WebMCP

BC WebMCP separates the public extension contract from its internal dispatcher.
Another extension can add operations to Customer, Vendor, or Item, or host the
generic FactBox on a different card page.

## Host the FactBox on another table

Add the public `BC WebMCP FactBox` part to the card and pass the current record
context whenever navigation changes:

```al
pageextension 70000 "Resource Card WebMCP" extends "Resource Card"
{
    layout
    {
        addlast(FactBoxes)
        {
            part(BCWebMCP; "BC WebMCP FactBox")
            {
                ApplicationArea = All;
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    begin
        CurrPage.BCWebMCP.Page.SetContext(Rec.RecordId());
    end;
}
```

The generic primary-key tool is automatically available for any persisted
record. A new or deleted record produces a structured context error.

## Register a table-specific tool

Subscribe to `BC WebMCP Interface.OnDiscoverTools`. Tool names must be unique
within the current table context. Use a publisher-specific prefix for custom
operations and do not reuse the built-in `bc_` names.

```al
[EventSubscriber(ObjectType::Codeunit, Codeunit::"BC WebMCP Interface", 'OnDiscoverTools', '', false, false)]
local procedure DiscoverResourceTools(TableId: Integer; var ToolDefinitions: JsonArray)
var
    WebMCPInterface: Codeunit "BC WebMCP Interface";
    InputSchema: JsonObject;
    Properties: JsonObject;
    Annotations: JsonObject;
begin
    if TableId <> Database::Resource then
        exit;

    InputSchema.Add('type', 'object');
    InputSchema.Add('properties', Properties);
    InputSchema.Add('additionalProperties', false);
    Annotations.Add('readOnlyHint', true);

    WebMCPInterface.AddToolDefinition(
        ToolDefinitions,
        'contoso_get_resource_capacity',
        'Get resource capacity',
        'Returns capacity information for the current Resource.',
        InputSchema,
        Annotations);
end;
```

## Execute the tool

Handle the matching name in `OnExecuteTool`. Exit immediately when `Handled` is
already true so exactly one subscriber owns an invocation. Return a serialized
JSON object in `ResultJson`.

```al
[EventSubscriber(ObjectType::Codeunit, Codeunit::"BC WebMCP Interface", 'OnExecuteTool', '', false, false)]
local procedure ExecuteResourceTool(ContextRecordId: RecordId; ToolName: Text; Arguments: JsonObject; var ResultJson: Text; var ErrorCode: Text; var ErrorMessage: Text; var IsError: Boolean; var Handled: Boolean)
var
    Resource: Record Resource;
    RecordReference: RecordRef;
    Result: JsonObject;
begin
    if Handled or (ToolName <> 'contoso_get_resource_capacity') then
        exit;
    if ContextRecordId.TableNo() <> Database::Resource then
        exit;

    Handled := true;
    if not RecordReference.Get(ContextRecordId) then begin
        ErrorCode := 'RECORD_NOT_FOUND';
        ErrorMessage := 'The Resource no longer exists.';
        IsError := true;
        exit;
    end;

    RecordReference.SetTable(Resource);
    Resource.CalcFields(Capacity);
    Result.Add('number', Resource."No.");
    Result.Add('capacity', Resource.Capacity);
    Result.WriteTo(ResultJson);
end;
```

Custom write tools must set suitable WebMCP annotations and must not use elevated
permissions to bypass the current Business Central user. Subscribers can also
implement `OnGetLastAccessed` when their table has an equivalent timestamp that
should appear in the generic FactBox.

Built-in definitions cannot be overridden for Customer, Vendor, or Item.
Duplicate names are rejected before JavaScript registration and the error is
shown in the FactBox.
