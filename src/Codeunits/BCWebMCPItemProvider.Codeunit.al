codeunit 50108 "BC WebMCP Item Provider"
{
    Access = Internal;

    procedure Execute(ContextRecordId: RecordId; ToolName: Text; Arguments: JsonObject; var ResultJson: Text; var ErrorCode: Text; var ErrorMessage: Text): Boolean
    var
        Management: Codeunit "BC WebMCP Management";
    begin
        Clear(ErrorCode);
        Clear(ErrorMessage);

        if ToolName = Management.GetRecordInfoToolName() then begin
            GetRecordInfo(ContextRecordId, ResultJson);
            exit(true);
        end;
        if ToolName = Management.GetFinancialInfoToolName() then begin
            GetFinancialInfo(ContextRecordId, ResultJson);
            exit(true);
        end;
        if ToolName = Management.GetLedgerEntriesToolName() then begin
            GetLedgerEntries(ContextRecordId, Arguments, ResultJson, ErrorCode, ErrorMessage);
            exit(true);
        end;
        if ToolName = Management.GetDocumentsToolName() then begin
            GetDocuments(ContextRecordId, Arguments, ResultJson, ErrorCode, ErrorMessage);
            exit(true);
        end;
        if ToolName = Management.GetSetLastAccessedToolName() then begin
            SetLastAccessed(ContextRecordId, ResultJson);
            exit(true);
        end;
        exit(false);
    end;

    local procedure GetRecordInfo(ContextRecordId: RecordId; var ResultJson: Text)
    var
        Item: Record Item;
        Management: Codeunit "BC WebMCP Management";
        RecordReference: RecordRef;
        Result: JsonObject;
        Data: JsonObject;
    begin
        RecordReference.Get(ContextRecordId);
        RecordReference.SetTable(Item);
        Item.CalcFields(Inventory);
        Management.AddRecordContext(RecordReference, Result);
        Data.Add('recordType', 'item');
        Data.Add('number', Item."No.");
        Data.Add('description', Item.Description);
        Data.Add('description2', Item."Description 2");
        Data.Add('type', Format(Item.Type));
        Data.Add('blocked', Item.Blocked);
        Data.Add('baseUnitOfMeasure', Item."Base Unit of Measure");
        Data.Add('inventory', Item.Inventory);
        Data.Add('unitPrice', Item."Unit Price");
        if Item."Last Accessed by WebMCP" <> 0DT then
            Data.Add('lastAccessedByWebMCP', Item."Last Accessed by WebMCP");
        Result.Add('data', Data);
        Result.WriteTo(ResultJson);
    end;

    local procedure GetFinancialInfo(ContextRecordId: RecordId; var ResultJson: Text)
    var
        Item: Record Item;
        Management: Codeunit "BC WebMCP Management";
        DataHelper: Codeunit "BC WebMCP Data Helper";
        RecordReference: RecordRef;
        Result: JsonObject;
        Data: JsonObject;
        PostingGroups: JsonObject;
    begin
        RecordReference.Get(ContextRecordId);
        RecordReference.SetTable(Item);
        Item.CalcFields(Inventory, "Qty. on Sales Order", "Qty. on Purch. Order");
        Management.AddRecordContext(RecordReference, Result);
        Data.Add('recordType', 'item');
        Data.Add('inventory', Item.Inventory);
        Data.Add('quantityOnSalesOrder', Item."Qty. on Sales Order");
        Data.Add('quantityOnPurchaseOrder', Item."Qty. on Purch. Order");
        Data.Add('unitPrice', Item."Unit Price");
        Data.Add('unitCost', Item."Unit Cost");
        Data.Add('standardCost', Item."Standard Cost");
        Data.Add('lastDirectCost', Item."Last Direct Cost");
        Data.Add('costingMethod', Format(Item."Costing Method"));
        PostingGroups.Add('inventoryPostingGroup', Item."Inventory Posting Group");
        PostingGroups.Add('generalProductPostingGroup', Item."Gen. Prod. Posting Group");
        PostingGroups.Add('vatProductPostingGroup', Item."VAT Prod. Posting Group");
        Data.Add('postingGroups', PostingGroups);
        DataHelper.AddDefaultDimensions(Database::Item, Item."No.", Data);
        Result.Add('data', Data);
        Result.WriteTo(ResultJson);
    end;

    local procedure GetLedgerEntries(ContextRecordId: RecordId; Arguments: JsonObject; var ResultJson: Text; var ErrorCode: Text; var ErrorMessage: Text)
    var
        Item: Record Item;
        ItemLedgerEntry: Record "Item Ledger Entry";
        Setup: Record "BC WebMCP Setup";
        Management: Codeunit "BC WebMCP Management";
        RecordReference: RecordRef;
        Result: JsonObject;
        Entries: JsonArray;
        Entry: JsonObject;
        AppliedCount: Integer;
        RequestedCount: Integer;
        ReturnedCount: Integer;
        UsedDefault: Boolean;
        HasMore: Boolean;
    begin
        Management.GetSetup(Setup);
        if not Management.ResolveCount(Arguments, Setup."Default Ledger Entry Count", Setup."Maximum Ledger Entry Count", AppliedCount, RequestedCount, UsedDefault, ErrorMessage) then begin
            ErrorCode := 'INVALID_ARGUMENTS';
            exit;
        end;

        RecordReference.Get(ContextRecordId);
        RecordReference.SetTable(Item);
        ItemLedgerEntry.SetRange("Item No.", Item."No.");
        ItemLedgerEntry.SetCurrentKey("Entry No.");
        ItemLedgerEntry.Ascending(false);
        if ItemLedgerEntry.FindSet() then
            repeat
                if ReturnedCount = AppliedCount then begin
                    HasMore := true;
                    break;
                end;
                ItemLedgerEntry.CalcFields("Cost Amount (Actual)", "Sales Amount (Actual)", "Purchase Amount (Actual)");
                Clear(Entry);
                Entry.Add('entryNo', ItemLedgerEntry."Entry No.");
                Entry.Add('postingDate', ItemLedgerEntry."Posting Date");
                Entry.Add('documentDate', ItemLedgerEntry."Document Date");
                Entry.Add('entryType', Format(ItemLedgerEntry."Entry Type"));
                Entry.Add('documentType', Format(ItemLedgerEntry."Document Type"));
                Entry.Add('documentNo', ItemLedgerEntry."Document No.");
                Entry.Add('description', ItemLedgerEntry.Description);
                Entry.Add('locationCode', ItemLedgerEntry."Location Code");
                Entry.Add('variantCode', ItemLedgerEntry."Variant Code");
                Entry.Add('quantity', ItemLedgerEntry.Quantity);
                Entry.Add('remainingQuantity', ItemLedgerEntry."Remaining Quantity");
                Entry.Add('open', ItemLedgerEntry.Open);
                Entry.Add('costAmountActual', ItemLedgerEntry."Cost Amount (Actual)");
                Entry.Add('salesAmountActual', ItemLedgerEntry."Sales Amount (Actual)");
                Entry.Add('purchaseAmountActual', ItemLedgerEntry."Purchase Amount (Actual)");
                Entries.Add(Entry);
                ReturnedCount += 1;
            until ItemLedgerEntry.Next() = 0;

        Management.AddRecordContext(RecordReference, Result);
        Management.AddCountMetadata(Result, RequestedCount, UsedDefault, AppliedCount, ReturnedCount, HasMore);
        Result.Add('entries', Entries);
        Result.WriteTo(ResultJson);
    end;

    local procedure GetDocuments(ContextRecordId: RecordId; Arguments: JsonObject; var ResultJson: Text; var ErrorCode: Text; var ErrorMessage: Text)
    var
        DocumentProvider: Codeunit "BC WebMCP Document Provider";
    begin
        DocumentProvider.GetDocuments(ContextRecordId, Arguments, ResultJson, ErrorCode, ErrorMessage);
    end;

    local procedure SetLastAccessed(ContextRecordId: RecordId; var ResultJson: Text)
    var
        Item: Record Item;
        Management: Codeunit "BC WebMCP Management";
        RecordReference: RecordRef;
        Result: JsonObject;
        Data: JsonObject;
        PreviousValue: DateTime;
        NewValue: DateTime;
    begin
        RecordReference.Get(ContextRecordId);
        RecordReference.SetTable(Item);
        PreviousValue := Item."Last Accessed by WebMCP";
        NewValue := CurrentDateTime();
        Item."Last Accessed by WebMCP" := NewValue;
        Item.Modify(false);
        RecordReference.GetTable(Item);
        Management.AddRecordContext(RecordReference, Result);
        Data.Add('previousLastAccessedByWebMCP', PreviousValue);
        Data.Add('lastAccessedByWebMCP', NewValue);
        Result.Add('data', Data);
        Result.WriteTo(ResultJson);
    end;
}
