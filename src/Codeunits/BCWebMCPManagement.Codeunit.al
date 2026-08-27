codeunit 50104 "BC WebMCP Management"
{
    Access = Internal;
    Permissions = tabledata "BC WebMCP Setup" = rimd;

    procedure EnsureSetup()
    var
        Setup: Record "BC WebMCP Setup";
        SetupChanged: Boolean;
    begin
        if Setup.Get() then begin
            if Setup."Maximum List Count" = 0 then begin
                Setup.Validate("Maximum List Count", 100);
                SetupChanged := true;
            end;
            if Setup."Default List Count" = 0 then begin
                Setup.Validate("Default List Count", 20);
                SetupChanged := true;
            end;
            if SetupChanged then
                Setup.Modify(true);
            exit;
        end;

        Setup.Init();
        Setup."Primary Key" := '';
        Setup.Validate("Default Ledger Entry Count", 10);
        Setup.Validate("Maximum Ledger Entry Count", 100);
        Setup.Validate("Default Document Count", 10);
        Setup.Validate("Maximum Document Count", 20);
        Setup.Validate("Default List Count", 20);
        Setup.Validate("Maximum List Count", 100);
        Setup.Insert(true);
    end;

    procedure GetSetup(var Setup: Record "BC WebMCP Setup")
    begin
        EnsureSetup();
        Setup.Get();
    end;

    procedure GetToolDefinitions(ContextRecordId: RecordId; var ToolDefinitionsJson: Text; var ErrorCode: Text; var ErrorMessage: Text): Boolean
    begin
        Clear(ToolDefinitionsJson);
        Clear(ErrorCode);
        Clear(ErrorMessage);

        if ContextRecordId.TableNo() = 0 then begin
            ErrorCode := 'NO_CURRENT_RECORD';
            ErrorMessage := 'The FactBox has no current Business Central record.';
            exit(false);
        end;

        if not TryBuildToolDefinitions(ContextRecordId.TableNo(), ToolDefinitionsJson, ErrorCode, ErrorMessage) then begin
            ErrorCode := 'TOOL_REGISTRATION_ERROR';
            ErrorMessage := GetLastErrorText();
            exit(false);
        end;

        exit(ErrorCode = '');
    end;

    procedure GetListToolDefinitions(ContextTableId: Integer; var ToolDefinitionsJson: Text; var ErrorCode: Text; var ErrorMessage: Text): Boolean
    begin
        Clear(ToolDefinitionsJson);
        Clear(ErrorCode);
        Clear(ErrorMessage);

        if ContextTableId = 0 then begin
            ErrorCode := 'NO_LIST_CONTEXT';
            ErrorMessage := 'The FactBox has no current Business Central list context.';
            exit(false);
        end;

        if not IsBuiltInTable(ContextTableId) then begin
            ErrorCode := 'UNSUPPORTED_LIST_TABLE';
            ErrorMessage := 'The current Business Central table does not support list reading through WebMCP.';
            exit(false);
        end;

        if not TryBuildListToolDefinitions(ToolDefinitionsJson) then begin
            ErrorCode := 'TOOL_REGISTRATION_ERROR';
            ErrorMessage := GetLastErrorText();
            exit(false);
        end;

        exit(true);
    end;

    [TryFunction]
    local procedure TryBuildListToolDefinitions(var ToolDefinitionsJson: Text)
    var
        ToolDefinitions: JsonArray;
    begin
        AddCountTool(
            ToolDefinitions,
            GetCurrentListToolName(),
            'Get current Business Central list',
            'Returns rows in the current page filter and sort order. The response includes totalCount and isLimited. If isLimited is true, disclose that the answer covers only returnedCount of totalCount records and do not present rankings as complete.');
        ToolDefinitions.WriteTo(ToolDefinitionsJson);
    end;

    [TryFunction]
    local procedure TryBuildToolDefinitions(TableId: Integer; var ToolDefinitionsJson: Text; var ErrorCode: Text; var ErrorMessage: Text)
    var
        WebMCPInterface: Codeunit "BC WebMCP Interface";
        ToolDefinitions: JsonArray;
    begin
        AddNoArgumentTool(ToolDefinitions, GetPrimaryKeyToolName(), 'Get current Business Central record key', 'Returns the table identity and primary-key fields of the current Business Central record.', true, false);

        if IsBuiltInTable(TableId) then begin
            AddNoArgumentTool(ToolDefinitions, GetRecordInfoToolName(), 'Get current record information', 'Returns basic information for the current Customer, Vendor, or Item.', true, false);
            AddNoArgumentTool(ToolDefinitions, GetFinancialInfoToolName(), 'Get current record financial information', 'Returns financial information, posting setup, and default dimensions for the current record.', true, false);
            AddCountTool(ToolDefinitions, GetLedgerEntriesToolName(), 'Get current record ledger entries', 'Returns the newest ledger entries for the current record.');
            AddDocumentsTool(ToolDefinitions);
            AddNoArgumentTool(ToolDefinitions, GetSetLastAccessedToolName(), 'Set WebMCP last-accessed timestamp', 'Sets Last Accessed by WebMCP on the current record to the current date and time.', false, false);
        end;

        WebMCPInterface.OnDiscoverTools(TableId, ToolDefinitions);
        if not ValidateToolDefinitions(ToolDefinitions, ErrorCode, ErrorMessage) then
            exit;

        ToolDefinitions.WriteTo(ToolDefinitionsJson);
    end;

    procedure ExecuteTool(ContextRecordId: RecordId; ToolName: Text; ArgumentsJson: Text; var ResultJson: Text; var IsError: Boolean)
    var
        UnhandledErrorMessage: Text;
    begin
        Clear(ResultJson);
        IsError := false;

        if not TryExecuteTool(ContextRecordId, ToolName, ArgumentsJson, ResultJson, IsError) then begin
            UnhandledErrorMessage := GetLastErrorText();
            if UnhandledErrorMessage = '' then
                UnhandledErrorMessage := 'Business Central could not complete the requested operation.';
            BuildErrorJson(GetUnhandledErrorCode(UnhandledErrorMessage), UnhandledErrorMessage, ResultJson);
            IsError := true;
        end;
    end;

    procedure ExecuteListTool(ContextTableId: Integer; ContextView: Text; ToolName: Text; ArgumentsJson: Text; var ResultJson: Text; var IsError: Boolean)
    var
        UnhandledErrorMessage: Text;
    begin
        Clear(ResultJson);
        IsError := false;

        if not TryExecuteListTool(ContextTableId, ContextView, ToolName, ArgumentsJson, ResultJson, IsError) then begin
            UnhandledErrorMessage := GetLastErrorText();
            if UnhandledErrorMessage = '' then
                UnhandledErrorMessage := 'Business Central could not complete the requested list operation.';
            BuildErrorJson(GetUnhandledErrorCode(UnhandledErrorMessage), UnhandledErrorMessage, ResultJson);
            IsError := true;
        end;
    end;

    [TryFunction]
    local procedure TryExecuteListTool(ContextTableId: Integer; ContextView: Text; ToolName: Text; ArgumentsJson: Text; var ResultJson: Text; var IsError: Boolean)
    var
        ListProvider: Codeunit "BC WebMCP List Provider";
        Arguments: JsonObject;
        ErrorCode: Text;
        ErrorMessage: Text;
    begin
        if ContextTableId = 0 then begin
            BuildErrorJson('NO_LIST_CONTEXT', 'The FactBox has no current Business Central list context.', ResultJson);
            IsError := true;
            exit;
        end;

        if not IsBuiltInTable(ContextTableId) then begin
            BuildErrorJson('UNSUPPORTED_LIST_TABLE', 'The current Business Central table does not support list reading through WebMCP.', ResultJson);
            IsError := true;
            exit;
        end;

        if ArgumentsJson = '' then
            ArgumentsJson := '{}';
        if not Arguments.ReadFrom(ArgumentsJson) then begin
            BuildErrorJson('INVALID_ARGUMENTS', 'The tool arguments are not a valid JSON object.', ResultJson);
            IsError := true;
            exit;
        end;

        if ToolName <> GetCurrentListToolName() then begin
            BuildErrorJson('UNKNOWN_TOOL', 'The requested WebMCP tool is not supported for the current list.', ResultJson);
            IsError := true;
            exit;
        end;

        ListProvider.Execute(ContextTableId, ContextView, Arguments, ResultJson, ErrorCode, ErrorMessage);
        if ErrorCode <> '' then begin
            BuildErrorJson(ErrorCode, ErrorMessage, ResultJson);
            IsError := true;
        end;
    end;

    [TryFunction]
    local procedure TryExecuteTool(ContextRecordId: RecordId; ToolName: Text; ArgumentsJson: Text; var ResultJson: Text; var IsError: Boolean)
    var
        CustomerProvider: Codeunit "BC WebMCP Customer Provider";
        VendorProvider: Codeunit "BC WebMCP Vendor Provider";
        ItemProvider: Codeunit "BC WebMCP Item Provider";
        WebMCPInterface: Codeunit "BC WebMCP Interface";
        RecordReference: RecordRef;
        Arguments: JsonObject;
        ErrorCode: Text;
        ErrorMessage: Text;
        Handled: Boolean;
    begin
        if ContextRecordId.TableNo() = 0 then begin
            BuildErrorJson('NO_CURRENT_RECORD', 'The FactBox has no current Business Central record.', ResultJson);
            IsError := true;
            exit;
        end;

        if not RecordReference.Get(ContextRecordId) then begin
            BuildErrorJson('RECORD_NOT_FOUND', 'The current Business Central record no longer exists.', ResultJson);
            IsError := true;
            exit;
        end;

        if ArgumentsJson = '' then
            ArgumentsJson := '{}';
        if not Arguments.ReadFrom(ArgumentsJson) then begin
            BuildErrorJson('INVALID_ARGUMENTS', 'The tool arguments are not a valid JSON object.', ResultJson);
            IsError := true;
            exit;
        end;

        if ToolName = GetPrimaryKeyToolName() then begin
            BuildPrimaryKeyResult(RecordReference, ResultJson);
            exit;
        end;

        case ContextRecordId.TableNo() of
            Database::Customer:
                Handled := CustomerProvider.Execute(ContextRecordId, ToolName, Arguments, ResultJson, ErrorCode, ErrorMessage);
            Database::Vendor:
                Handled := VendorProvider.Execute(ContextRecordId, ToolName, Arguments, ResultJson, ErrorCode, ErrorMessage);
            Database::Item:
                Handled := ItemProvider.Execute(ContextRecordId, ToolName, Arguments, ResultJson, ErrorCode, ErrorMessage);
        end;

        if Handled then begin
            if ErrorCode <> '' then begin
                BuildErrorJson(ErrorCode, ErrorMessage, ResultJson);
                IsError := true;
            end;
            exit;
        end;

        WebMCPInterface.OnExecuteTool(ContextRecordId, ToolName, Arguments, ResultJson, ErrorCode, ErrorMessage, IsError, Handled);
        if not Handled then begin
            BuildErrorJson('UNKNOWN_TOOL', 'The requested WebMCP tool is not supported for the current record.', ResultJson);
            IsError := true;
            exit;
        end;

        if IsError and (ErrorCode <> '') then
            BuildErrorJson(ErrorCode, ErrorMessage, ResultJson);
    end;

    procedure GetLastAccessed(ContextRecordId: RecordId; var LastAccessed: DateTime): Boolean
    var
        Customer: Record Customer;
        Vendor: Record Vendor;
        Item: Record Item;
        WebMCPInterface: Codeunit "BC WebMCP Interface";
        RecordReference: RecordRef;
        Handled: Boolean;
    begin
        Clear(LastAccessed);
        if ContextRecordId.TableNo() = 0 then
            exit(false);
        if not RecordReference.Get(ContextRecordId) then
            exit(false);

        case ContextRecordId.TableNo() of
            Database::Customer:
                begin
                    RecordReference.SetTable(Customer);
                    LastAccessed := Customer."Last Accessed by WebMCP";
                    exit(true);
                end;
            Database::Vendor:
                begin
                    RecordReference.SetTable(Vendor);
                    LastAccessed := Vendor."Last Accessed by WebMCP";
                    exit(true);
                end;
            Database::Item:
                begin
                    RecordReference.SetTable(Item);
                    LastAccessed := Item."Last Accessed by WebMCP";
                    exit(true);
                end;
        end;

        WebMCPInterface.OnGetLastAccessed(ContextRecordId, LastAccessed, Handled);
        exit(Handled);
    end;

    procedure ResolveCount(Arguments: JsonObject; DefaultCount: Integer; MaximumCount: Integer; var AppliedCount: Integer; var RequestedCount: Integer; var UsedDefault: Boolean; var ErrorMessage: Text): Boolean
    var
        CountToken: JsonToken;
    begin
        Clear(ErrorMessage);
        RequestedCount := 0;
        UsedDefault := not Arguments.Get('count', CountToken);

        if UsedDefault then
            AppliedCount := DefaultCount
        else begin
            if not CountToken.IsValue() then begin
                ErrorMessage := 'count must be a positive integer.';
                exit(false);
            end;
            if not TryGetInteger(CountToken, RequestedCount) then begin
                ErrorMessage := 'count must be a positive integer.';
                exit(false);
            end;
            if RequestedCount <= 0 then begin
                ErrorMessage := 'count must be a positive integer.';
                exit(false);
            end;
            AppliedCount := RequestedCount;
        end;

        if AppliedCount > MaximumCount then
            AppliedCount := MaximumCount;
        exit(true);
    end;

    [TryFunction]
    local procedure TryGetInteger(Token: JsonToken; var Value: Integer)
    begin
        Value := Token.AsValue().AsInteger();
    end;

    procedure AddRecordContext(RecordReference: RecordRef; var Result: JsonObject)
    var
        PrimaryKeyReference: KeyRef;
        KeyFieldReference: FieldRef;
        Context: JsonObject;
        Fields: JsonArray;
        FieldObject: JsonObject;
        FieldIndex: Integer;
    begin
        PrimaryKeyReference := RecordReference.KeyIndex(1);
        Context.Add('tableId', RecordReference.Number());
        Context.Add('tableName', RecordReference.Name());
        Context.Add('primaryKeyPosition', RecordReference.GetPosition(true));

        for FieldIndex := 1 to PrimaryKeyReference.FieldCount() do begin
            Clear(FieldObject);
            KeyFieldReference := PrimaryKeyReference.FieldIndex(FieldIndex);
            FieldObject.Add('fieldNo', KeyFieldReference.Number());
            FieldObject.Add('fieldName', KeyFieldReference.Name());
            FieldObject.Add('value', Format(KeyFieldReference.Value()));
            Fields.Add(FieldObject);
        end;
        Context.Add('primaryKeyFields', Fields);
        Result.Add('context', Context);
    end;

    procedure AddCountMetadata(var Result: JsonObject; RequestedCount: Integer; UsedDefault: Boolean; AppliedCount: Integer; ReturnedCount: Integer; HasMore: Boolean)
    begin
        if UsedDefault then
            Result.Add('requestedCount', AppliedCount)
        else
            Result.Add('requestedCount', RequestedCount);
        Result.Add('usedDefault', UsedDefault);
        Result.Add('appliedCount', AppliedCount);
        Result.Add('returnedCount', ReturnedCount);
        Result.Add('hasMore', HasMore);
    end;

    procedure AddListCountMetadata(var Result: JsonObject; RequestedCount: Integer; UsedDefault: Boolean; AppliedCount: Integer; ReturnedCount: Integer; TotalCount: Integer)
    var
        IsLimited: Boolean;
    begin
        IsLimited := ReturnedCount < TotalCount;
        AddCountMetadata(Result, RequestedCount, UsedDefault, AppliedCount, ReturnedCount, IsLimited);
        Result.Add('totalCount', TotalCount);
        Result.Add('isLimited', IsLimited);
    end;

    procedure AddListContext(TableId: Integer; PageView: Text; var Result: JsonObject)
    var
        RecordReference: RecordRef;
        Context: JsonObject;
    begin
        RecordReference.Open(TableId);
        Context.Add('contextType', 'list');
        Context.Add('tableId', TableId);
        Context.Add('tableName', RecordReference.Name());
        Context.Add('pageView', PageView);
        Result.Add('context', Context);
    end;

    procedure GetPrimaryKeyToolName(): Text
    begin
        exit('bc_get_current_record_primary_key');
    end;

    procedure GetRecordInfoToolName(): Text
    begin
        exit('bc_get_record_info');
    end;

    procedure GetFinancialInfoToolName(): Text
    begin
        exit('bc_get_financial_info');
    end;

    procedure GetLedgerEntriesToolName(): Text
    begin
        exit('bc_get_ledger_entries');
    end;

    procedure GetDocumentsToolName(): Text
    begin
        exit('bc_get_documents');
    end;

    procedure GetSetLastAccessedToolName(): Text
    begin
        exit('bc_set_last_accessed_by_webmcp');
    end;

    procedure GetCurrentListToolName(): Text
    begin
        exit('bc_get_current_list');
    end;

    local procedure IsBuiltInTable(TableId: Integer): Boolean
    begin
        exit(TableId in [Database::Customer, Database::Vendor, Database::Item]);
    end;

    local procedure AddNoArgumentTool(var ToolDefinitions: JsonArray; ToolName: Text; Title: Text; Description: Text; ReadOnly: Boolean; Destructive: Boolean)
    var
        WebMCPInterface: Codeunit "BC WebMCP Interface";
        InputSchema: JsonObject;
        Properties: JsonObject;
        Annotations: JsonObject;
    begin
        InputSchema.Add('type', 'object');
        InputSchema.Add('properties', Properties);
        InputSchema.Add('additionalProperties', false);
        Annotations.Add('readOnlyHint', ReadOnly);
        Annotations.Add('destructiveHint', Destructive);
        WebMCPInterface.AddToolDefinition(ToolDefinitions, ToolName, Title, Description, InputSchema, Annotations);
    end;

    local procedure AddCountTool(var ToolDefinitions: JsonArray; ToolName: Text; Title: Text; Description: Text)
    var
        WebMCPInterface: Codeunit "BC WebMCP Interface";
        InputSchema: JsonObject;
        Properties: JsonObject;
        CountSchema: JsonObject;
        Annotations: JsonObject;
    begin
        CountSchema.Add('type', 'integer');
        CountSchema.Add('minimum', 1);
        CountSchema.Add('description', 'Optional number of records to return. The configured maximum is always enforced.');
        Properties.Add('count', CountSchema);
        InputSchema.Add('type', 'object');
        InputSchema.Add('properties', Properties);
        InputSchema.Add('additionalProperties', false);
        Annotations.Add('readOnlyHint', true);
        WebMCPInterface.AddToolDefinition(ToolDefinitions, ToolName, Title, Description, InputSchema, Annotations);
    end;

    local procedure AddDocumentsTool(var ToolDefinitions: JsonArray)
    var
        WebMCPInterface: Codeunit "BC WebMCP Interface";
        InputSchema: JsonObject;
        Properties: JsonObject;
        KindSchema: JsonObject;
        CountSchema: JsonObject;
        Annotations: JsonObject;
        Required: JsonArray;
        Kinds: JsonArray;
    begin
        AddDocumentKinds(Kinds);
        KindSchema.Add('type', 'string');
        KindSchema.Add('enum', Kinds);
        KindSchema.Add('description', 'The standard Business Central document kind to return.');
        CountSchema.Add('type', 'integer');
        CountSchema.Add('minimum', 1);
        CountSchema.Add('description', 'Optional number of document headers to return. The configured maximum is always enforced.');
        Properties.Add('documentKind', KindSchema);
        Properties.Add('count', CountSchema);
        Required.Add('documentKind');
        InputSchema.Add('type', 'object');
        InputSchema.Add('properties', Properties);
        InputSchema.Add('required', Required);
        InputSchema.Add('additionalProperties', false);
        Annotations.Add('readOnlyHint', true);
        WebMCPInterface.AddToolDefinition(ToolDefinitions, GetDocumentsToolName(), 'Get current record documents', 'Returns matching unposted or posted document headers and all their lines.', InputSchema, Annotations);
    end;

    local procedure AddDocumentKinds(var Kinds: JsonArray)
    begin
        Kinds.Add('salesQuote');
        Kinds.Add('salesOrder');
        Kinds.Add('salesInvoice');
        Kinds.Add('salesCreditMemo');
        Kinds.Add('salesBlanketOrder');
        Kinds.Add('salesReturnOrder');
        Kinds.Add('postedSalesInvoice');
        Kinds.Add('postedSalesCreditMemo');
        Kinds.Add('postedSalesShipment');
        Kinds.Add('postedSalesReturnReceipt');
        Kinds.Add('purchaseQuote');
        Kinds.Add('purchaseOrder');
        Kinds.Add('purchaseInvoice');
        Kinds.Add('purchaseCreditMemo');
        Kinds.Add('purchaseBlanketOrder');
        Kinds.Add('purchaseReturnOrder');
        Kinds.Add('postedPurchaseInvoice');
        Kinds.Add('postedPurchaseCreditMemo');
        Kinds.Add('postedPurchaseReceipt');
        Kinds.Add('postedPurchaseReturnShipment');
    end;

    local procedure ValidateToolDefinitions(ToolDefinitions: JsonArray; var ErrorCode: Text; var ErrorMessage: Text): Boolean
    var
        Names: Dictionary of [Text, Boolean];
        ToolToken: JsonToken;
        NameToken: JsonToken;
        ToolName: Text;
    begin
        foreach ToolToken in ToolDefinitions do begin
            if (not ToolToken.IsObject()) or (not ToolToken.AsObject().Get('name', NameToken)) or (not NameToken.IsValue()) then begin
                ErrorCode := 'INVALID_TOOL_DEFINITION';
                ErrorMessage := 'A registered tool definition does not contain a valid name.';
                exit(false);
            end;
            ToolName := NameToken.AsValue().AsText();
            if Names.ContainsKey(ToolName) then begin
                ErrorCode := 'DUPLICATE_TOOL';
                ErrorMessage := StrSubstNo('WebMCP tool %1 is registered more than once for this table.', ToolName);
                exit(false);
            end;
            Names.Add(ToolName, true);
        end;
        exit(true);
    end;

    local procedure BuildPrimaryKeyResult(RecordReference: RecordRef; var ResultJson: Text)
    var
        Result: JsonObject;
    begin
        AddRecordContext(RecordReference, Result);
        Result.WriteTo(ResultJson);
    end;

    local procedure BuildErrorJson(ErrorCode: Text; ErrorMessage: Text; var ErrorJson: Text)
    var
        ErrorObject: JsonObject;
    begin
        ErrorObject.Add('code', ErrorCode);
        ErrorObject.Add('message', ErrorMessage);
        ErrorObject.WriteTo(ErrorJson);
    end;

    local procedure GetUnhandledErrorCode(ErrorMessage: Text): Text
    begin
        if StrPos(LowerCase(ErrorMessage), 'permission') <> 0 then
            exit('PERMISSION_DENIED');
        exit('AL_ERROR');
    end;
}
