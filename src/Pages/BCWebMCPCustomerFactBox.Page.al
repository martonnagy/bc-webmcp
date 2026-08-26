page 50100 "BC WebMCP Customer FactBox"
{
    PageType = CardPart;
    SourceTable = Customer;
    ApplicationArea = All;
    Caption = 'BC WebMCP';
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            usercontrol(WebMCPBridge; "BC WebMCP Bridge")
            {
                ApplicationArea = All;

                trigger InvokeTool(RequestId: Text; ToolName: Text; ArgumentsJson: Text)
                var
                    ResultJson: Text;
                begin
                    if ToolName <> GetPrimaryKeyToolName() then begin
                        ResultJson := BuildErrorJson('UNKNOWN_TOOL', 'The requested WebMCP tool is not supported.');
                        CurrPage.WebMCPBridge.CompleteToolCall(RequestId, ResultJson, true);
                        exit;
                    end;

                    if Rec."No." = '' then begin
                        ResultJson := BuildErrorJson('NO_CURRENT_RECORD', 'The FactBox has no current Customer record.');
                        CurrPage.WebMCPBridge.CompleteToolCall(RequestId, ResultJson, true);
                        exit;
                    end;

                    ResultJson := BuildCurrentPrimaryKeyJson();
                    CurrPage.WebMCPBridge.CompleteToolCall(RequestId, ResultJson, false);
                end;
            }
        }
    }

    local procedure GetPrimaryKeyToolName(): Text
    begin
        exit('bc_get_current_record_primary_key');
    end;

    local procedure BuildCurrentPrimaryKeyJson(): Text
    var
        RecordReference: RecordRef;
        PrimaryKeyReference: KeyRef;
        KeyFieldReference: FieldRef;
        ResultJsonObject: JsonObject;
        FieldsJsonArray: JsonArray;
        FieldJsonObject: JsonObject;
        ResultJson: Text;
        FieldIndex: Integer;
    begin
        RecordReference.GetTable(Rec);
        PrimaryKeyReference := RecordReference.KeyIndex(1);

        ResultJsonObject.Add('application', 'Microsoft Dynamics 365 Business Central');
        ResultJsonObject.Add('tableId', RecordReference.Number());
        ResultJsonObject.Add('tableName', RecordReference.Name());
        ResultJsonObject.Add('primaryKeyPosition', RecordReference.GetPosition(true));

        for FieldIndex := 1 to PrimaryKeyReference.FieldCount() do begin
            Clear(FieldJsonObject);
            KeyFieldReference := PrimaryKeyReference.FieldIndex(FieldIndex);
            FieldJsonObject.Add('fieldNo', KeyFieldReference.Number());
            FieldJsonObject.Add('fieldName', KeyFieldReference.Name());
            FieldJsonObject.Add('value', Format(KeyFieldReference.Value()));
            FieldsJsonArray.Add(FieldJsonObject);
        end;

        ResultJsonObject.Add('primaryKeyFields', FieldsJsonArray);
        ResultJsonObject.WriteTo(ResultJson);
        exit(ResultJson);
    end;

    local procedure BuildErrorJson(ErrorCode: Text; ErrorMessage: Text): Text
    var
        ErrorJsonObject: JsonObject;
        ErrorJson: Text;
    begin
        ErrorJsonObject.Add('code', ErrorCode);
        ErrorJsonObject.Add('message', ErrorMessage);
        ErrorJsonObject.WriteTo(ErrorJson);
        exit(ErrorJson);
    end;
}
