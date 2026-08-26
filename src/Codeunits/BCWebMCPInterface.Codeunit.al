codeunit 50105 "BC WebMCP Interface"
{
    Access = Public;

    procedure AddToolDefinition(var ToolDefinitions: JsonArray; ToolName: Text; ToolTitle: Text; ToolDescription: Text; InputSchema: JsonObject; Annotations: JsonObject)
    var
        ToolDefinition: JsonObject;
    begin
        if ToolName = '' then
            Error(ToolNameRequiredErr);
        if ToolTitle = '' then
            Error(ToolTitleRequiredErr, ToolName);
        if ToolDescription = '' then
            Error(ToolDescriptionRequiredErr, ToolName);

        ToolDefinition.Add('name', ToolName);
        ToolDefinition.Add('title', ToolTitle);
        ToolDefinition.Add('description', ToolDescription);
        ToolDefinition.Add('inputSchema', InputSchema);
        ToolDefinition.Add('annotations', Annotations);
        ToolDefinitions.Add(ToolDefinition);
    end;

    [IntegrationEvent(false, false)]
    procedure OnDiscoverTools(TableId: Integer; var ToolDefinitions: JsonArray)
    begin
    end;

    [IntegrationEvent(false, false)]
    procedure OnExecuteTool(ContextRecordId: RecordId; ToolName: Text; Arguments: JsonObject; var ResultJson: Text; var ErrorCode: Text; var ErrorMessage: Text; var IsError: Boolean; var Handled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    procedure OnGetLastAccessed(ContextRecordId: RecordId; var LastAccessed: DateTime; var Handled: Boolean)
    begin
    end;

    var
        ToolNameRequiredErr: Label 'A WebMCP tool name is required.';
        ToolTitleRequiredErr: Label 'A title is required for WebMCP tool %1.';
        ToolDescriptionRequiredErr: Label 'A description is required for WebMCP tool %1.';
}
