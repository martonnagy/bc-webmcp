codeunit 50109 "BC WebMCP Document Provider"
{
    Access = Internal;

    procedure GetDocuments(ContextRecordId: RecordId; Arguments: JsonObject; var ResultJson: Text; var ErrorCode: Text; var ErrorMessage: Text)
    var
        Setup: Record "BC WebMCP Setup";
        DocumentBuffer: Record "BC WebMCP Document Buffer" temporary;
        Management: Codeunit "BC WebMCP Management";
        Serializer: Codeunit "BC WebMCP Doc. Serializer";
        RecordReference: RecordRef;
        KindToken: JsonToken;
        Result: JsonObject;
        Documents: JsonArray;
        Document: JsonObject;
        BufferIndex: Dictionary of [Text, Integer];
        DocumentKind: Text;
        RecordNo: Code[20];
        AppliedCount: Integer;
        RequestedCount: Integer;
        ReturnedCount: Integer;
        UsedDefault: Boolean;
        HasMore: Boolean;
        NextEntryNo: Integer;
    begin
        if (not Arguments.Get('documentKind', KindToken)) or (not KindToken.IsValue()) then begin
            ErrorCode := 'INVALID_ARGUMENTS';
            ErrorMessage := 'documentKind is required and must be a string.';
            exit;
        end;
        DocumentKind := KindToken.AsValue().AsText();
        if not IsKnownDocumentKind(DocumentKind) then begin
            ErrorCode := 'UNSUPPORTED_DOCUMENT_KIND';
            ErrorMessage := StrSubstNo('%1 is not a supported document kind.', DocumentKind);
            exit;
        end;
        if not IsKindSupportedForTable(ContextRecordId.TableNo(), DocumentKind) then begin
            ErrorCode := 'UNSUPPORTED_DOCUMENT_KIND';
            ErrorMessage := StrSubstNo('%1 is not supported for the current record type.', DocumentKind);
            exit;
        end;

        Management.GetSetup(Setup);
        if not Management.ResolveCount(Arguments, Setup."Default Document Count", Setup."Maximum Document Count", AppliedCount, RequestedCount, UsedDefault, ErrorMessage) then begin
            ErrorCode := 'INVALID_ARGUMENTS';
            exit;
        end;

        RecordReference.Get(ContextRecordId);
        RecordNo := GetRecordNo(RecordReference);
        PopulateDocumentBuffer(DocumentBuffer, BufferIndex, NextEntryNo, ContextRecordId.TableNo(), RecordNo, DocumentKind);

        DocumentBuffer.SetCurrentKey("Sort Date", "Document No.");
        DocumentBuffer.Ascending(false);
        if DocumentBuffer.FindSet() then
            repeat
                if ReturnedCount = AppliedCount then begin
                    HasMore := true;
                    break;
                end;
                Clear(Document);
                Serializer.Serialize(DocumentBuffer, DocumentKind, ContextRecordId.TableNo(), RecordNo, Document);
                Documents.Add(Document);
                ReturnedCount += 1;
            until DocumentBuffer.Next() = 0;

        Management.AddRecordContext(RecordReference, Result);
        Result.Add('documentKind', DocumentKind);
        Management.AddCountMetadata(Result, RequestedCount, UsedDefault, AppliedCount, ReturnedCount, HasMore);
        Result.Add('documents', Documents);
        Result.WriteTo(ResultJson);
    end;

    local procedure GetRecordNo(RecordReference: RecordRef): Code[20]
    var
        Customer: Record Customer;
        Vendor: Record Vendor;
        Item: Record Item;
    begin
        case RecordReference.Number() of
            Database::Customer:
                begin
                    RecordReference.SetTable(Customer);
                    exit(Customer."No.");
                end;
            Database::Vendor:
                begin
                    RecordReference.SetTable(Vendor);
                    exit(Vendor."No.");
                end;
            Database::Item:
                begin
                    RecordReference.SetTable(Item);
                    exit(Item."No.");
                end;
        end;
    end;

    local procedure PopulateDocumentBuffer(var DocumentBuffer: Record "BC WebMCP Document Buffer" temporary; var BufferIndex: Dictionary of [Text, Integer]; var NextEntryNo: Integer; TableId: Integer; RecordNo: Code[20]; DocumentKind: Text)
    var
        SalesDocumentType: Enum "Sales Document Type";
        PurchaseDocumentType: Enum "Purchase Document Type";
    begin
        if GetSalesDocumentType(DocumentKind, SalesDocumentType) then begin
            PopulateSalesHeaders(DocumentBuffer, BufferIndex, NextEntryNo, TableId, RecordNo, SalesDocumentType);
            exit;
        end;
        if GetPurchaseDocumentType(DocumentKind, PurchaseDocumentType) then begin
            PopulatePurchaseHeaders(DocumentBuffer, BufferIndex, NextEntryNo, TableId, RecordNo, PurchaseDocumentType);
            exit;
        end;

        case DocumentKind of
            'postedSalesInvoice':
                PopulateSalesInvoices(DocumentBuffer, BufferIndex, NextEntryNo, TableId, RecordNo);
            'postedSalesCreditMemo':
                PopulateSalesCreditMemos(DocumentBuffer, BufferIndex, NextEntryNo, TableId, RecordNo);
            'postedSalesShipment':
                PopulateSalesShipments(DocumentBuffer, BufferIndex, NextEntryNo, TableId, RecordNo);
            'postedSalesReturnReceipt':
                PopulateSalesReturnReceipts(DocumentBuffer, BufferIndex, NextEntryNo, TableId, RecordNo);
            'postedPurchaseInvoice':
                PopulatePurchaseInvoices(DocumentBuffer, BufferIndex, NextEntryNo, TableId, RecordNo);
            'postedPurchaseCreditMemo':
                PopulatePurchaseCreditMemos(DocumentBuffer, BufferIndex, NextEntryNo, TableId, RecordNo);
            'postedPurchaseReceipt':
                PopulatePurchaseReceipts(DocumentBuffer, BufferIndex, NextEntryNo, TableId, RecordNo);
            'postedPurchaseReturnShipment':
                PopulatePurchaseReturnShipments(DocumentBuffer, BufferIndex, NextEntryNo, TableId, RecordNo);
        end;
    end;

    local procedure PopulateSalesHeaders(var DocumentBuffer: Record "BC WebMCP Document Buffer" temporary; var BufferIndex: Dictionary of [Text, Integer]; var NextEntryNo: Integer; TableId: Integer; RecordNo: Code[20]; DocumentType: Enum "Sales Document Type")
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
    begin
        if TableId = Database::Customer then begin
            SalesHeader.SetRange("Document Type", DocumentType);
            SalesHeader.SetRange("Sell-to Customer No.", RecordNo);
            if SalesHeader.FindSet() then
                repeat
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, SalesHeader.RecordId(), SalesHeader."Document Date", SalesHeader."No.", 'sellTo');
                until SalesHeader.Next() = 0;

            SalesHeader.Reset();
            SalesHeader.SetRange("Document Type", DocumentType);
            SalesHeader.SetRange("Bill-to Customer No.", RecordNo);
            if SalesHeader.FindSet() then
                repeat
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, SalesHeader.RecordId(), SalesHeader."Document Date", SalesHeader."No.", 'billTo');
                until SalesHeader.Next() = 0;
            exit;
        end;

        SalesLine.SetRange("Document Type", DocumentType);
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.SetRange("No.", RecordNo);
        if SalesLine.FindSet() then
            repeat
                if SalesHeader.Get(DocumentType, SalesLine."Document No.") then
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, SalesHeader.RecordId(), SalesHeader."Document Date", SalesHeader."No.", '');
            until SalesLine.Next() = 0;
    end;

    local procedure PopulatePurchaseHeaders(var DocumentBuffer: Record "BC WebMCP Document Buffer" temporary; var BufferIndex: Dictionary of [Text, Integer]; var NextEntryNo: Integer; TableId: Integer; RecordNo: Code[20]; DocumentType: Enum "Purchase Document Type")
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
    begin
        if TableId = Database::Vendor then begin
            PurchaseHeader.SetRange("Document Type", DocumentType);
            PurchaseHeader.SetRange("Buy-from Vendor No.", RecordNo);
            if PurchaseHeader.FindSet() then
                repeat
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, PurchaseHeader.RecordId(), PurchaseHeader."Document Date", PurchaseHeader."No.", 'buyFrom');
                until PurchaseHeader.Next() = 0;

            PurchaseHeader.Reset();
            PurchaseHeader.SetRange("Document Type", DocumentType);
            PurchaseHeader.SetRange("Pay-to Vendor No.", RecordNo);
            if PurchaseHeader.FindSet() then
                repeat
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, PurchaseHeader.RecordId(), PurchaseHeader."Document Date", PurchaseHeader."No.", 'payTo');
                until PurchaseHeader.Next() = 0;
            exit;
        end;

        PurchaseLine.SetRange("Document Type", DocumentType);
        PurchaseLine.SetRange(Type, PurchaseLine.Type::Item);
        PurchaseLine.SetRange("No.", RecordNo);
        if PurchaseLine.FindSet() then
            repeat
                if PurchaseHeader.Get(DocumentType, PurchaseLine."Document No.") then
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, PurchaseHeader.RecordId(), PurchaseHeader."Document Date", PurchaseHeader."No.", '');
            until PurchaseLine.Next() = 0;
    end;

    local procedure PopulateSalesInvoices(var DocumentBuffer: Record "BC WebMCP Document Buffer" temporary; var BufferIndex: Dictionary of [Text, Integer]; var NextEntryNo: Integer; TableId: Integer; RecordNo: Code[20])
    var
        Header: Record "Sales Invoice Header";
        Line: Record "Sales Invoice Line";
    begin
        if TableId = Database::Customer then begin
            Header.SetRange("Sell-to Customer No.", RecordNo);
            if Header.FindSet() then
                repeat
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, Header.RecordId(), Header."Posting Date", Header."No.", 'sellTo');
                until Header.Next() = 0;
            Header.Reset();
            Header.SetRange("Bill-to Customer No.", RecordNo);
            if Header.FindSet() then
                repeat
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, Header.RecordId(), Header."Posting Date", Header."No.", 'billTo');
                until Header.Next() = 0;
            exit;
        end;
        Line.SetRange(Type, Line.Type::Item);
        Line.SetRange("No.", RecordNo);
        if Line.FindSet() then
            repeat
                if Header.Get(Line."Document No.") then
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, Header.RecordId(), Header."Posting Date", Header."No.", '');
            until Line.Next() = 0;
    end;

    local procedure PopulateSalesCreditMemos(var DocumentBuffer: Record "BC WebMCP Document Buffer" temporary; var BufferIndex: Dictionary of [Text, Integer]; var NextEntryNo: Integer; TableId: Integer; RecordNo: Code[20])
    var
        Header: Record "Sales Cr.Memo Header";
        Line: Record "Sales Cr.Memo Line";
    begin
        if TableId = Database::Customer then begin
            Header.SetRange("Sell-to Customer No.", RecordNo);
            if Header.FindSet() then
                repeat
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, Header.RecordId(), Header."Posting Date", Header."No.", 'sellTo');
                until Header.Next() = 0;
            Header.Reset();
            Header.SetRange("Bill-to Customer No.", RecordNo);
            if Header.FindSet() then
                repeat
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, Header.RecordId(), Header."Posting Date", Header."No.", 'billTo');
                until Header.Next() = 0;
            exit;
        end;
        Line.SetRange(Type, Line.Type::Item);
        Line.SetRange("No.", RecordNo);
        if Line.FindSet() then
            repeat
                if Header.Get(Line."Document No.") then
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, Header.RecordId(), Header."Posting Date", Header."No.", '');
            until Line.Next() = 0;
    end;

    local procedure PopulateSalesShipments(var DocumentBuffer: Record "BC WebMCP Document Buffer" temporary; var BufferIndex: Dictionary of [Text, Integer]; var NextEntryNo: Integer; TableId: Integer; RecordNo: Code[20])
    var
        Header: Record "Sales Shipment Header";
        Line: Record "Sales Shipment Line";
    begin
        if TableId = Database::Customer then begin
            Header.SetRange("Sell-to Customer No.", RecordNo);
            if Header.FindSet() then
                repeat
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, Header.RecordId(), Header."Posting Date", Header."No.", 'sellTo');
                until Header.Next() = 0;
            Header.Reset();
            Header.SetRange("Bill-to Customer No.", RecordNo);
            if Header.FindSet() then
                repeat
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, Header.RecordId(), Header."Posting Date", Header."No.", 'billTo');
                until Header.Next() = 0;
            exit;
        end;
        Line.SetRange(Type, Line.Type::Item);
        Line.SetRange("No.", RecordNo);
        if Line.FindSet() then
            repeat
                if Header.Get(Line."Document No.") then
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, Header.RecordId(), Header."Posting Date", Header."No.", '');
            until Line.Next() = 0;
    end;

    local procedure PopulateSalesReturnReceipts(var DocumentBuffer: Record "BC WebMCP Document Buffer" temporary; var BufferIndex: Dictionary of [Text, Integer]; var NextEntryNo: Integer; TableId: Integer; RecordNo: Code[20])
    var
        Header: Record "Return Receipt Header";
        Line: Record "Return Receipt Line";
    begin
        if TableId = Database::Customer then begin
            Header.SetRange("Sell-to Customer No.", RecordNo);
            if Header.FindSet() then
                repeat
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, Header.RecordId(), Header."Posting Date", Header."No.", 'sellTo');
                until Header.Next() = 0;
            Header.Reset();
            Header.SetRange("Bill-to Customer No.", RecordNo);
            if Header.FindSet() then
                repeat
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, Header.RecordId(), Header."Posting Date", Header."No.", 'billTo');
                until Header.Next() = 0;
            exit;
        end;
        Line.SetRange(Type, Line.Type::Item);
        Line.SetRange("No.", RecordNo);
        if Line.FindSet() then
            repeat
                if Header.Get(Line."Document No.") then
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, Header.RecordId(), Header."Posting Date", Header."No.", '');
            until Line.Next() = 0;
    end;

    local procedure PopulatePurchaseInvoices(var DocumentBuffer: Record "BC WebMCP Document Buffer" temporary; var BufferIndex: Dictionary of [Text, Integer]; var NextEntryNo: Integer; TableId: Integer; RecordNo: Code[20])
    var
        Header: Record "Purch. Inv. Header";
        Line: Record "Purch. Inv. Line";
    begin
        if TableId = Database::Vendor then begin
            Header.SetRange("Buy-from Vendor No.", RecordNo);
            if Header.FindSet() then
                repeat
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, Header.RecordId(), Header."Posting Date", Header."No.", 'buyFrom');
                until Header.Next() = 0;
            Header.Reset();
            Header.SetRange("Pay-to Vendor No.", RecordNo);
            if Header.FindSet() then
                repeat
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, Header.RecordId(), Header."Posting Date", Header."No.", 'payTo');
                until Header.Next() = 0;
            exit;
        end;
        Line.SetRange(Type, Line.Type::Item);
        Line.SetRange("No.", RecordNo);
        if Line.FindSet() then
            repeat
                if Header.Get(Line."Document No.") then
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, Header.RecordId(), Header."Posting Date", Header."No.", '');
            until Line.Next() = 0;
    end;

    local procedure PopulatePurchaseCreditMemos(var DocumentBuffer: Record "BC WebMCP Document Buffer" temporary; var BufferIndex: Dictionary of [Text, Integer]; var NextEntryNo: Integer; TableId: Integer; RecordNo: Code[20])
    var
        Header: Record "Purch. Cr. Memo Hdr.";
        Line: Record "Purch. Cr. Memo Line";
    begin
        if TableId = Database::Vendor then begin
            Header.SetRange("Buy-from Vendor No.", RecordNo);
            if Header.FindSet() then
                repeat
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, Header.RecordId(), Header."Posting Date", Header."No.", 'buyFrom');
                until Header.Next() = 0;
            Header.Reset();
            Header.SetRange("Pay-to Vendor No.", RecordNo);
            if Header.FindSet() then
                repeat
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, Header.RecordId(), Header."Posting Date", Header."No.", 'payTo');
                until Header.Next() = 0;
            exit;
        end;
        Line.SetRange(Type, Line.Type::Item);
        Line.SetRange("No.", RecordNo);
        if Line.FindSet() then
            repeat
                if Header.Get(Line."Document No.") then
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, Header.RecordId(), Header."Posting Date", Header."No.", '');
            until Line.Next() = 0;
    end;

    local procedure PopulatePurchaseReceipts(var DocumentBuffer: Record "BC WebMCP Document Buffer" temporary; var BufferIndex: Dictionary of [Text, Integer]; var NextEntryNo: Integer; TableId: Integer; RecordNo: Code[20])
    var
        Header: Record "Purch. Rcpt. Header";
        Line: Record "Purch. Rcpt. Line";
    begin
        if TableId = Database::Vendor then begin
            Header.SetRange("Buy-from Vendor No.", RecordNo);
            if Header.FindSet() then
                repeat
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, Header.RecordId(), Header."Posting Date", Header."No.", 'buyFrom');
                until Header.Next() = 0;
            Header.Reset();
            Header.SetRange("Pay-to Vendor No.", RecordNo);
            if Header.FindSet() then
                repeat
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, Header.RecordId(), Header."Posting Date", Header."No.", 'payTo');
                until Header.Next() = 0;
            exit;
        end;
        Line.SetRange(Type, Line.Type::Item);
        Line.SetRange("No.", RecordNo);
        if Line.FindSet() then
            repeat
                if Header.Get(Line."Document No.") then
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, Header.RecordId(), Header."Posting Date", Header."No.", '');
            until Line.Next() = 0;
    end;

    local procedure PopulatePurchaseReturnShipments(var DocumentBuffer: Record "BC WebMCP Document Buffer" temporary; var BufferIndex: Dictionary of [Text, Integer]; var NextEntryNo: Integer; TableId: Integer; RecordNo: Code[20])
    var
        Header: Record "Return Shipment Header";
        Line: Record "Return Shipment Line";
    begin
        if TableId = Database::Vendor then begin
            Header.SetRange("Buy-from Vendor No.", RecordNo);
            if Header.FindSet() then
                repeat
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, Header.RecordId(), Header."Posting Date", Header."No.", 'buyFrom');
                until Header.Next() = 0;
            Header.Reset();
            Header.SetRange("Pay-to Vendor No.", RecordNo);
            if Header.FindSet() then
                repeat
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, Header.RecordId(), Header."Posting Date", Header."No.", 'payTo');
                until Header.Next() = 0;
            exit;
        end;
        Line.SetRange(Type, Line.Type::Item);
        Line.SetRange("No.", RecordNo);
        if Line.FindSet() then
            repeat
                if Header.Get(Line."Document No.") then
                    AddBufferEntry(DocumentBuffer, BufferIndex, NextEntryNo, Header.RecordId(), Header."Posting Date", Header."No.", '');
            until Line.Next() = 0;
    end;

    local procedure AddBufferEntry(var DocumentBuffer: Record "BC WebMCP Document Buffer" temporary; var BufferIndex: Dictionary of [Text, Integer]; var NextEntryNo: Integer; HeaderRecordId: RecordId; SortDate: Date; DocumentNo: Code[20]; MatchedRole: Text)
    var
        RecordKey: Text;
    begin
        RecordKey := Format(HeaderRecordId);
        if BufferIndex.ContainsKey(RecordKey) then begin
            BufferIndex.Get(RecordKey, DocumentBuffer."Entry No.");
            DocumentBuffer.Get(DocumentBuffer."Entry No.");
            AddMatchedRole(DocumentBuffer, MatchedRole);
            DocumentBuffer.Modify();
            exit;
        end;

        NextEntryNo += 1;
        DocumentBuffer.Init();
        DocumentBuffer."Entry No." := NextEntryNo;
        DocumentBuffer."Sort Date" := SortDate;
        DocumentBuffer."Document No." := DocumentNo;
        DocumentBuffer."Header Record ID" := HeaderRecordId;
        DocumentBuffer."Header Table ID" := HeaderRecordId.TableNo();
        AddMatchedRole(DocumentBuffer, MatchedRole);
        DocumentBuffer.Insert();
        BufferIndex.Add(RecordKey, NextEntryNo);
    end;

    local procedure AddMatchedRole(var DocumentBuffer: Record "BC WebMCP Document Buffer" temporary; MatchedRole: Text)
    begin
        if MatchedRole = '' then
            exit;
        if StrPos('|' + DocumentBuffer."Matched Roles" + '|', '|' + MatchedRole + '|') <> 0 then
            exit;
        if DocumentBuffer."Matched Roles" <> '' then
            DocumentBuffer."Matched Roles" += '|';
        DocumentBuffer."Matched Roles" += MatchedRole;
    end;

    local procedure GetSalesDocumentType(DocumentKind: Text; var DocumentType: Enum "Sales Document Type"): Boolean
    begin
        case DocumentKind of
            'salesQuote':
                DocumentType := DocumentType::Quote;
            'salesOrder':
                DocumentType := DocumentType::Order;
            'salesInvoice':
                DocumentType := DocumentType::Invoice;
            'salesCreditMemo':
                DocumentType := DocumentType::"Credit Memo";
            'salesBlanketOrder':
                DocumentType := DocumentType::"Blanket Order";
            'salesReturnOrder':
                DocumentType := DocumentType::"Return Order";
            else
                exit(false);
        end;
        exit(true);
    end;

    local procedure GetPurchaseDocumentType(DocumentKind: Text; var DocumentType: Enum "Purchase Document Type"): Boolean
    begin
        case DocumentKind of
            'purchaseQuote':
                DocumentType := DocumentType::Quote;
            'purchaseOrder':
                DocumentType := DocumentType::Order;
            'purchaseInvoice':
                DocumentType := DocumentType::Invoice;
            'purchaseCreditMemo':
                DocumentType := DocumentType::"Credit Memo";
            'purchaseBlanketOrder':
                DocumentType := DocumentType::"Blanket Order";
            'purchaseReturnOrder':
                DocumentType := DocumentType::"Return Order";
            else
                exit(false);
        end;
        exit(true);
    end;

    local procedure IsKnownDocumentKind(DocumentKind: Text): Boolean
    begin
        exit(IsSalesKind(DocumentKind) or IsPurchaseKind(DocumentKind));
    end;

    local procedure IsKindSupportedForTable(TableId: Integer; DocumentKind: Text): Boolean
    begin
        case TableId of
            Database::Customer:
                exit(IsSalesKind(DocumentKind));
            Database::Vendor:
                exit(IsPurchaseKind(DocumentKind));
            Database::Item:
                exit(IsSalesKind(DocumentKind) or IsPurchaseKind(DocumentKind));
        end;
        exit(false);
    end;

    local procedure IsSalesKind(DocumentKind: Text): Boolean
    begin
        exit(DocumentKind in ['salesQuote', 'salesOrder', 'salesInvoice', 'salesCreditMemo', 'salesBlanketOrder', 'salesReturnOrder', 'postedSalesInvoice', 'postedSalesCreditMemo', 'postedSalesShipment', 'postedSalesReturnReceipt']);
    end;

    local procedure IsPurchaseKind(DocumentKind: Text): Boolean
    begin
        exit(DocumentKind in ['purchaseQuote', 'purchaseOrder', 'purchaseInvoice', 'purchaseCreditMemo', 'purchaseBlanketOrder', 'purchaseReturnOrder', 'postedPurchaseInvoice', 'postedPurchaseCreditMemo', 'postedPurchaseReceipt', 'postedPurchaseReturnShipment']);
    end;
}
