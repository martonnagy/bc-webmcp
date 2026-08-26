codeunit 50107 "BC WebMCP Vendor Provider"
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
        Vendor: Record Vendor;
        Management: Codeunit "BC WebMCP Management";
        RecordReference: RecordRef;
        Result: JsonObject;
        Data: JsonObject;
    begin
        RecordReference.Get(ContextRecordId);
        RecordReference.SetTable(Vendor);
        Vendor.CalcFields(Balance);
        Management.AddRecordContext(RecordReference, Result);
        Data.Add('recordType', 'vendor');
        Data.Add('number', Vendor."No.");
        Data.Add('name', Vendor.Name);
        Data.Add('name2', Vendor."Name 2");
        Data.Add('blocked', Format(Vendor.Blocked));
        Data.Add('address', Vendor.Address);
        Data.Add('address2', Vendor."Address 2");
        Data.Add('city', Vendor.City);
        Data.Add('postCode', Vendor."Post Code");
        Data.Add('countryRegionCode', Vendor."Country/Region Code");
        Data.Add('contact', Vendor.Contact);
        Data.Add('phoneNo', Vendor."Phone No.");
        Data.Add('email', Vendor."E-Mail");
        Data.Add('currencyCode', Vendor."Currency Code");
        Data.Add('balance', Vendor.Balance);
        if Vendor."Last Accessed by WebMCP" <> 0DT then
            Data.Add('lastAccessedByWebMCP', Vendor."Last Accessed by WebMCP");
        Result.Add('data', Data);
        Result.WriteTo(ResultJson);
    end;

    local procedure GetFinancialInfo(ContextRecordId: RecordId; var ResultJson: Text)
    var
        Vendor: Record Vendor;
        Management: Codeunit "BC WebMCP Management";
        DataHelper: Codeunit "BC WebMCP Data Helper";
        RecordReference: RecordRef;
        Result: JsonObject;
        Data: JsonObject;
        PostingGroups: JsonObject;
    begin
        RecordReference.Get(ContextRecordId);
        RecordReference.SetTable(Vendor);
        Vendor.CalcFields(Balance, "Balance (LCY)", "Balance Due", "Balance Due (LCY)");
        Management.AddRecordContext(RecordReference, Result);
        Data.Add('recordType', 'vendor');
        Data.Add('currencyCode', Vendor."Currency Code");
        Data.Add('balance', Vendor.Balance);
        Data.Add('balanceLCY', Vendor."Balance (LCY)");
        Data.Add('balanceDue', Vendor."Balance Due");
        Data.Add('balanceDueLCY', Vendor."Balance Due (LCY)");
        Data.Add('paymentTermsCode', Vendor."Payment Terms Code");
        Data.Add('paymentMethodCode', Vendor."Payment Method Code");
        PostingGroups.Add('vendorPostingGroup', Vendor."Vendor Posting Group");
        PostingGroups.Add('generalBusinessPostingGroup', Vendor."Gen. Bus. Posting Group");
        PostingGroups.Add('vatBusinessPostingGroup', Vendor."VAT Bus. Posting Group");
        Data.Add('postingGroups', PostingGroups);
        DataHelper.AddDefaultDimensions(Database::Vendor, Vendor."No.", Data);
        Result.Add('data', Data);
        Result.WriteTo(ResultJson);
    end;

    local procedure GetLedgerEntries(ContextRecordId: RecordId; Arguments: JsonObject; var ResultJson: Text; var ErrorCode: Text; var ErrorMessage: Text)
    var
        Vendor: Record Vendor;
        VendorLedgerEntry: Record "Vendor Ledger Entry";
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
        RecordReference.SetTable(Vendor);
        VendorLedgerEntry.SetRange("Vendor No.", Vendor."No.");
        VendorLedgerEntry.SetCurrentKey("Entry No.");
        VendorLedgerEntry.Ascending(false);
        if VendorLedgerEntry.FindSet() then
            repeat
                if ReturnedCount = AppliedCount then begin
                    HasMore := true;
                    break;
                end;
                VendorLedgerEntry.CalcFields(Amount, "Remaining Amount", "Amount (LCY)", "Remaining Amt. (LCY)");
                Clear(Entry);
                Entry.Add('entryNo', VendorLedgerEntry."Entry No.");
                Entry.Add('postingDate', VendorLedgerEntry."Posting Date");
                Entry.Add('documentDate', VendorLedgerEntry."Document Date");
                Entry.Add('documentType', Format(VendorLedgerEntry."Document Type"));
                Entry.Add('documentNo', VendorLedgerEntry."Document No.");
                Entry.Add('externalDocumentNo', VendorLedgerEntry."External Document No.");
                Entry.Add('description', VendorLedgerEntry.Description);
                Entry.Add('currencyCode', VendorLedgerEntry."Currency Code");
                Entry.Add('amount', VendorLedgerEntry.Amount);
                Entry.Add('remainingAmount', VendorLedgerEntry."Remaining Amount");
                Entry.Add('amountLCY', VendorLedgerEntry."Amount (LCY)");
                Entry.Add('remainingAmountLCY', VendorLedgerEntry."Remaining Amt. (LCY)");
                Entry.Add('dueDate', VendorLedgerEntry."Due Date");
                Entry.Add('open', VendorLedgerEntry.Open);
                Entries.Add(Entry);
                ReturnedCount += 1;
            until VendorLedgerEntry.Next() = 0;

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
        Vendor: Record Vendor;
        Management: Codeunit "BC WebMCP Management";
        RecordReference: RecordRef;
        Result: JsonObject;
        Data: JsonObject;
        PreviousValue: DateTime;
        NewValue: DateTime;
    begin
        RecordReference.Get(ContextRecordId);
        RecordReference.SetTable(Vendor);
        PreviousValue := Vendor."Last Accessed by WebMCP";
        NewValue := CurrentDateTime();
        Vendor."Last Accessed by WebMCP" := NewValue;
        Vendor.Modify(false);
        RecordReference.GetTable(Vendor);
        Management.AddRecordContext(RecordReference, Result);
        Data.Add('previousLastAccessedByWebMCP', PreviousValue);
        Data.Add('lastAccessedByWebMCP', NewValue);
        Result.Add('data', Data);
        Result.WriteTo(ResultJson);
    end;
}
