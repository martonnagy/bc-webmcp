codeunit 50122 "BC WebMCP Doc. Serializer"
{
    Access = Internal;

    procedure Serialize(DocumentBuffer: Record "BC WebMCP Document Buffer" temporary; DocumentKind: Text; ContextTableId: Integer; CurrentRecordNo: Code[20]; var Document: JsonObject)
    var
        RecordReference: RecordRef;
    begin
        RecordReference.Get(DocumentBuffer."Header Record ID");
        case DocumentBuffer."Header Table ID" of
            Database::"Sales Header":
                SerializeSalesHeader(RecordReference, DocumentBuffer, DocumentKind, ContextTableId, CurrentRecordNo, Document);
            Database::"Sales Invoice Header":
                SerializeSalesInvoice(RecordReference, DocumentBuffer, DocumentKind, ContextTableId, CurrentRecordNo, Document);
            Database::"Sales Cr.Memo Header":
                SerializeSalesCreditMemo(RecordReference, DocumentBuffer, DocumentKind, ContextTableId, CurrentRecordNo, Document);
            Database::"Sales Shipment Header":
                SerializeSalesShipment(RecordReference, DocumentBuffer, DocumentKind, ContextTableId, CurrentRecordNo, Document);
            Database::"Return Receipt Header":
                SerializeSalesReturnReceipt(RecordReference, DocumentBuffer, DocumentKind, ContextTableId, CurrentRecordNo, Document);
            Database::"Purchase Header":
                SerializePurchaseHeader(RecordReference, DocumentBuffer, DocumentKind, ContextTableId, CurrentRecordNo, Document);
            Database::"Purch. Inv. Header":
                SerializePurchaseInvoice(RecordReference, DocumentBuffer, DocumentKind, ContextTableId, CurrentRecordNo, Document);
            Database::"Purch. Cr. Memo Hdr.":
                SerializePurchaseCreditMemo(RecordReference, DocumentBuffer, DocumentKind, ContextTableId, CurrentRecordNo, Document);
            Database::"Purch. Rcpt. Header":
                SerializePurchaseReceipt(RecordReference, DocumentBuffer, DocumentKind, ContextTableId, CurrentRecordNo, Document);
            Database::"Return Shipment Header":
                SerializePurchaseReturnShipment(RecordReference, DocumentBuffer, DocumentKind, ContextTableId, CurrentRecordNo, Document);
        end;
    end;

    local procedure SerializeSalesHeader(RecordReference: RecordRef; DocumentBuffer: Record "BC WebMCP Document Buffer" temporary; DocumentKind: Text; ContextTableId: Integer; CurrentRecordNo: Code[20]; var Document: JsonObject)
    var
        Header: Record "Sales Header";
        Line: Record "Sales Line";
        Lines: JsonArray;
        LineObject: JsonObject;
        MatchingLineNumbers: JsonArray;
    begin
        RecordReference.SetTable(Header);
        Header.CalcFields(Amount, "Amount Including VAT");
        AddSalesHeaderFields(Document, DocumentBuffer, DocumentKind, false, Header."No.", Header."Sell-to Customer No.", Header."Bill-to Customer No.", Header."Order Date", Header."Posting Date", Header."Document Date", Header."Currency Code", Header."Location Code");
        Document.Add('status', Format(Header.Status));
        Document.Add('amount', Header.Amount);
        Document.Add('amountIncludingVAT', Header."Amount Including VAT");

        Line.SetRange("Document Type", Header."Document Type");
        Line.SetRange("Document No.", Header."No.");
        if Line.FindSet() then
            repeat
                Clear(LineObject);
                AddSalesLineFields(LineObject, Line."Line No.", Format(Line.Type), Line."No.", Line.Description, Line.Quantity, Line."Unit of Measure Code", Line."Variant Code", Line."Location Code", Line."Unit Price");
                LineObject.Add('outstandingQuantity', Line."Outstanding Quantity");
                LineObject.Add('lineAmount', Line."Line Amount");
                LineObject.Add('amount', Line.Amount);
                LineObject.Add('amountIncludingVAT', Line."Amount Including VAT");
                Lines.Add(LineObject);
                AddMatchingSalesLine(ContextTableId, CurrentRecordNo, Line.Type, Line."No.", Line."Line No.", MatchingLineNumbers);
            until Line.Next() = 0;
        Document.Add('lines', Lines);
        AddMatchingLines(ContextTableId, MatchingLineNumbers, Document);
    end;

    local procedure SerializeSalesInvoice(RecordReference: RecordRef; DocumentBuffer: Record "BC WebMCP Document Buffer" temporary; DocumentKind: Text; ContextTableId: Integer; CurrentRecordNo: Code[20]; var Document: JsonObject)
    var
        Header: Record "Sales Invoice Header";
        Line: Record "Sales Invoice Line";
        Lines: JsonArray;
        LineObject: JsonObject;
        MatchingLineNumbers: JsonArray;
    begin
        RecordReference.SetTable(Header);
        Header.CalcFields(Amount, "Amount Including VAT");
        AddSalesHeaderFields(Document, DocumentBuffer, DocumentKind, true, Header."No.", Header."Sell-to Customer No.", Header."Bill-to Customer No.", Header."Order Date", Header."Posting Date", Header."Document Date", Header."Currency Code", Header."Location Code");
        Document.Add('amount', Header.Amount);
        Document.Add('amountIncludingVAT', Header."Amount Including VAT");
        Line.SetRange("Document No.", Header."No.");
        if Line.FindSet() then
            repeat
                Clear(LineObject);
                AddSalesLineFields(LineObject, Line."Line No.", Format(Line.Type), Line."No.", Line.Description, Line.Quantity, Line."Unit of Measure Code", Line."Variant Code", Line."Location Code", Line."Unit Price");
                LineObject.Add('lineAmount', Line."Line Amount");
                LineObject.Add('amount', Line.Amount);
                LineObject.Add('amountIncludingVAT', Line."Amount Including VAT");
                Lines.Add(LineObject);
                AddMatchingSalesLine(ContextTableId, CurrentRecordNo, Line.Type, Line."No.", Line."Line No.", MatchingLineNumbers);
            until Line.Next() = 0;
        Document.Add('lines', Lines);
        AddMatchingLines(ContextTableId, MatchingLineNumbers, Document);
    end;

    local procedure SerializeSalesCreditMemo(RecordReference: RecordRef; DocumentBuffer: Record "BC WebMCP Document Buffer" temporary; DocumentKind: Text; ContextTableId: Integer; CurrentRecordNo: Code[20]; var Document: JsonObject)
    var
        Header: Record "Sales Cr.Memo Header";
        Line: Record "Sales Cr.Memo Line";
        Lines: JsonArray;
        LineObject: JsonObject;
        MatchingLineNumbers: JsonArray;
    begin
        RecordReference.SetTable(Header);
        Header.CalcFields(Amount, "Amount Including VAT");
        AddSalesHeaderFields(Document, DocumentBuffer, DocumentKind, true, Header."No.", Header."Sell-to Customer No.", Header."Bill-to Customer No.", 0D, Header."Posting Date", Header."Document Date", Header."Currency Code", Header."Location Code");
        Document.Add('amount', Header.Amount);
        Document.Add('amountIncludingVAT', Header."Amount Including VAT");
        Line.SetRange("Document No.", Header."No.");
        if Line.FindSet() then
            repeat
                Clear(LineObject);
                AddSalesLineFields(LineObject, Line."Line No.", Format(Line.Type), Line."No.", Line.Description, Line.Quantity, Line."Unit of Measure Code", Line."Variant Code", Line."Location Code", Line."Unit Price");
                LineObject.Add('lineAmount', Line."Line Amount");
                LineObject.Add('amount', Line.Amount);
                LineObject.Add('amountIncludingVAT', Line."Amount Including VAT");
                Lines.Add(LineObject);
                AddMatchingSalesLine(ContextTableId, CurrentRecordNo, Line.Type, Line."No.", Line."Line No.", MatchingLineNumbers);
            until Line.Next() = 0;
        Document.Add('lines', Lines);
        AddMatchingLines(ContextTableId, MatchingLineNumbers, Document);
    end;

    local procedure SerializeSalesShipment(RecordReference: RecordRef; DocumentBuffer: Record "BC WebMCP Document Buffer" temporary; DocumentKind: Text; ContextTableId: Integer; CurrentRecordNo: Code[20]; var Document: JsonObject)
    var
        Header: Record "Sales Shipment Header";
        Line: Record "Sales Shipment Line";
        Lines: JsonArray;
        LineObject: JsonObject;
        MatchingLineNumbers: JsonArray;
    begin
        RecordReference.SetTable(Header);
        AddSalesHeaderFields(Document, DocumentBuffer, DocumentKind, true, Header."No.", Header."Sell-to Customer No.", Header."Bill-to Customer No.", Header."Order Date", Header."Posting Date", Header."Document Date", Header."Currency Code", Header."Location Code");
        Line.SetRange("Document No.", Header."No.");
        if Line.FindSet() then
            repeat
                Clear(LineObject);
                AddSalesLineFields(LineObject, Line."Line No.", Format(Line.Type), Line."No.", Line.Description, Line.Quantity, Line."Unit of Measure Code", Line."Variant Code", Line."Location Code", Line."Unit Price");
                Lines.Add(LineObject);
                AddMatchingSalesLine(ContextTableId, CurrentRecordNo, Line.Type, Line."No.", Line."Line No.", MatchingLineNumbers);
            until Line.Next() = 0;
        Document.Add('lines', Lines);
        AddMatchingLines(ContextTableId, MatchingLineNumbers, Document);
    end;

    local procedure SerializeSalesReturnReceipt(RecordReference: RecordRef; DocumentBuffer: Record "BC WebMCP Document Buffer" temporary; DocumentKind: Text; ContextTableId: Integer; CurrentRecordNo: Code[20]; var Document: JsonObject)
    var
        Header: Record "Return Receipt Header";
        Line: Record "Return Receipt Line";
        Lines: JsonArray;
        LineObject: JsonObject;
        MatchingLineNumbers: JsonArray;
    begin
        RecordReference.SetTable(Header);
        AddSalesHeaderFields(Document, DocumentBuffer, DocumentKind, true, Header."No.", Header."Sell-to Customer No.", Header."Bill-to Customer No.", Header."Order Date", Header."Posting Date", Header."Document Date", Header."Currency Code", Header."Location Code");
        Line.SetRange("Document No.", Header."No.");
        if Line.FindSet() then
            repeat
                Clear(LineObject);
                AddSalesLineFields(LineObject, Line."Line No.", Format(Line.Type), Line."No.", Line.Description, Line.Quantity, Line."Unit of Measure Code", Line."Variant Code", Line."Location Code", Line."Unit Price");
                Lines.Add(LineObject);
                AddMatchingSalesLine(ContextTableId, CurrentRecordNo, Line.Type, Line."No.", Line."Line No.", MatchingLineNumbers);
            until Line.Next() = 0;
        Document.Add('lines', Lines);
        AddMatchingLines(ContextTableId, MatchingLineNumbers, Document);
    end;

    local procedure SerializePurchaseHeader(RecordReference: RecordRef; DocumentBuffer: Record "BC WebMCP Document Buffer" temporary; DocumentKind: Text; ContextTableId: Integer; CurrentRecordNo: Code[20]; var Document: JsonObject)
    var
        Header: Record "Purchase Header";
        Line: Record "Purchase Line";
        Lines: JsonArray;
        LineObject: JsonObject;
        MatchingLineNumbers: JsonArray;
    begin
        RecordReference.SetTable(Header);
        Header.CalcFields(Amount, "Amount Including VAT");
        AddPurchaseHeaderFields(Document, DocumentBuffer, DocumentKind, false, Header."No.", Header."Buy-from Vendor No.", Header."Pay-to Vendor No.", Header."Order Date", Header."Posting Date", Header."Document Date", Header."Currency Code", Header."Location Code");
        Document.Add('status', Format(Header.Status));
        Document.Add('amount', Header.Amount);
        Document.Add('amountIncludingVAT', Header."Amount Including VAT");
        Line.SetRange("Document Type", Header."Document Type");
        Line.SetRange("Document No.", Header."No.");
        if Line.FindSet() then
            repeat
                Clear(LineObject);
                AddPurchaseLineFields(LineObject, Line."Line No.", Format(Line.Type), Line."No.", Line.Description, Line.Quantity, Line."Unit of Measure Code", Line."Variant Code", Line."Location Code", Line."Direct Unit Cost");
                LineObject.Add('outstandingQuantity', Line."Outstanding Quantity");
                LineObject.Add('lineAmount', Line."Line Amount");
                LineObject.Add('amount', Line.Amount);
                LineObject.Add('amountIncludingVAT', Line."Amount Including VAT");
                Lines.Add(LineObject);
                AddMatchingPurchaseLine(ContextTableId, CurrentRecordNo, Line.Type, Line."No.", Line."Line No.", MatchingLineNumbers);
            until Line.Next() = 0;
        Document.Add('lines', Lines);
        AddMatchingLines(ContextTableId, MatchingLineNumbers, Document);
    end;

    local procedure SerializePurchaseInvoice(RecordReference: RecordRef; DocumentBuffer: Record "BC WebMCP Document Buffer" temporary; DocumentKind: Text; ContextTableId: Integer; CurrentRecordNo: Code[20]; var Document: JsonObject)
    var
        Header: Record "Purch. Inv. Header";
        Line: Record "Purch. Inv. Line";
        Lines: JsonArray;
        LineObject: JsonObject;
        MatchingLineNumbers: JsonArray;
    begin
        RecordReference.SetTable(Header);
        Header.CalcFields(Amount, "Amount Including VAT");
        AddPurchaseHeaderFields(Document, DocumentBuffer, DocumentKind, true, Header."No.", Header."Buy-from Vendor No.", Header."Pay-to Vendor No.", Header."Order Date", Header."Posting Date", Header."Document Date", Header."Currency Code", Header."Location Code");
        Document.Add('amount', Header.Amount);
        Document.Add('amountIncludingVAT', Header."Amount Including VAT");
        Line.SetRange("Document No.", Header."No.");
        if Line.FindSet() then
            repeat
                Clear(LineObject);
                AddPurchaseLineFields(LineObject, Line."Line No.", Format(Line.Type), Line."No.", Line.Description, Line.Quantity, Line."Unit of Measure Code", Line."Variant Code", Line."Location Code", Line."Direct Unit Cost");
                LineObject.Add('lineAmount', Line."Line Amount");
                LineObject.Add('amount', Line.Amount);
                LineObject.Add('amountIncludingVAT', Line."Amount Including VAT");
                Lines.Add(LineObject);
                AddMatchingPurchaseLine(ContextTableId, CurrentRecordNo, Line.Type, Line."No.", Line."Line No.", MatchingLineNumbers);
            until Line.Next() = 0;
        Document.Add('lines', Lines);
        AddMatchingLines(ContextTableId, MatchingLineNumbers, Document);
    end;

    local procedure SerializePurchaseCreditMemo(RecordReference: RecordRef; DocumentBuffer: Record "BC WebMCP Document Buffer" temporary; DocumentKind: Text; ContextTableId: Integer; CurrentRecordNo: Code[20]; var Document: JsonObject)
    var
        Header: Record "Purch. Cr. Memo Hdr.";
        Line: Record "Purch. Cr. Memo Line";
        Lines: JsonArray;
        LineObject: JsonObject;
        MatchingLineNumbers: JsonArray;
    begin
        RecordReference.SetTable(Header);
        Header.CalcFields(Amount, "Amount Including VAT");
        AddPurchaseHeaderFields(Document, DocumentBuffer, DocumentKind, true, Header."No.", Header."Buy-from Vendor No.", Header."Pay-to Vendor No.", 0D, Header."Posting Date", Header."Document Date", Header."Currency Code", Header."Location Code");
        Document.Add('amount', Header.Amount);
        Document.Add('amountIncludingVAT', Header."Amount Including VAT");
        Line.SetRange("Document No.", Header."No.");
        if Line.FindSet() then
            repeat
                Clear(LineObject);
                AddPurchaseLineFields(LineObject, Line."Line No.", Format(Line.Type), Line."No.", Line.Description, Line.Quantity, Line."Unit of Measure Code", Line."Variant Code", Line."Location Code", Line."Direct Unit Cost");
                LineObject.Add('lineAmount', Line."Line Amount");
                LineObject.Add('amount', Line.Amount);
                LineObject.Add('amountIncludingVAT', Line."Amount Including VAT");
                Lines.Add(LineObject);
                AddMatchingPurchaseLine(ContextTableId, CurrentRecordNo, Line.Type, Line."No.", Line."Line No.", MatchingLineNumbers);
            until Line.Next() = 0;
        Document.Add('lines', Lines);
        AddMatchingLines(ContextTableId, MatchingLineNumbers, Document);
    end;

    local procedure SerializePurchaseReceipt(RecordReference: RecordRef; DocumentBuffer: Record "BC WebMCP Document Buffer" temporary; DocumentKind: Text; ContextTableId: Integer; CurrentRecordNo: Code[20]; var Document: JsonObject)
    var
        Header: Record "Purch. Rcpt. Header";
        Line: Record "Purch. Rcpt. Line";
        Lines: JsonArray;
        LineObject: JsonObject;
        MatchingLineNumbers: JsonArray;
    begin
        RecordReference.SetTable(Header);
        AddPurchaseHeaderFields(Document, DocumentBuffer, DocumentKind, true, Header."No.", Header."Buy-from Vendor No.", Header."Pay-to Vendor No.", Header."Order Date", Header."Posting Date", Header."Document Date", Header."Currency Code", Header."Location Code");
        Line.SetRange("Document No.", Header."No.");
        if Line.FindSet() then
            repeat
                Clear(LineObject);
                AddPurchaseLineFields(LineObject, Line."Line No.", Format(Line.Type), Line."No.", Line.Description, Line.Quantity, Line."Unit of Measure Code", Line."Variant Code", Line."Location Code", Line."Direct Unit Cost");
                Lines.Add(LineObject);
                AddMatchingPurchaseLine(ContextTableId, CurrentRecordNo, Line.Type, Line."No.", Line."Line No.", MatchingLineNumbers);
            until Line.Next() = 0;
        Document.Add('lines', Lines);
        AddMatchingLines(ContextTableId, MatchingLineNumbers, Document);
    end;

    local procedure SerializePurchaseReturnShipment(RecordReference: RecordRef; DocumentBuffer: Record "BC WebMCP Document Buffer" temporary; DocumentKind: Text; ContextTableId: Integer; CurrentRecordNo: Code[20]; var Document: JsonObject)
    var
        Header: Record "Return Shipment Header";
        Line: Record "Return Shipment Line";
        Lines: JsonArray;
        LineObject: JsonObject;
        MatchingLineNumbers: JsonArray;
    begin
        RecordReference.SetTable(Header);
        AddPurchaseHeaderFields(Document, DocumentBuffer, DocumentKind, true, Header."No.", Header."Buy-from Vendor No.", Header."Pay-to Vendor No.", 0D, Header."Posting Date", Header."Document Date", Header."Currency Code", Header."Location Code");
        Line.SetRange("Document No.", Header."No.");
        if Line.FindSet() then
            repeat
                Clear(LineObject);
                AddPurchaseLineFields(LineObject, Line."Line No.", Format(Line.Type), Line."No.", Line.Description, Line.Quantity, Line."Unit of Measure Code", Line."Variant Code", Line."Location Code", Line."Direct Unit Cost");
                Lines.Add(LineObject);
                AddMatchingPurchaseLine(ContextTableId, CurrentRecordNo, Line.Type, Line."No.", Line."Line No.", MatchingLineNumbers);
            until Line.Next() = 0;
        Document.Add('lines', Lines);
        AddMatchingLines(ContextTableId, MatchingLineNumbers, Document);
    end;

    local procedure AddSalesHeaderFields(var Document: JsonObject; DocumentBuffer: Record "BC WebMCP Document Buffer" temporary; DocumentKind: Text; Posted: Boolean; DocumentNo: Code[20]; SellToCustomerNo: Code[20]; BillToCustomerNo: Code[20]; OrderDate: Date; PostingDate: Date; DocumentDate: Date; CurrencyCode: Code[10]; LocationCode: Code[10])
    begin
        Document.Add('documentKind', DocumentKind);
        Document.Add('posted', Posted);
        Document.Add('number', DocumentNo);
        Document.Add('sellToCustomerNo', SellToCustomerNo);
        Document.Add('billToCustomerNo', BillToCustomerNo);
        if OrderDate <> 0D then
            Document.Add('orderDate', OrderDate);
        if PostingDate <> 0D then
            Document.Add('postingDate', PostingDate);
        if DocumentDate <> 0D then
            Document.Add('documentDate', DocumentDate);
        Document.Add('currencyCode', CurrencyCode);
        Document.Add('locationCode', LocationCode);
        AddMatchedRoles(DocumentBuffer."Matched Roles", Document);
    end;

    local procedure AddPurchaseHeaderFields(var Document: JsonObject; DocumentBuffer: Record "BC WebMCP Document Buffer" temporary; DocumentKind: Text; Posted: Boolean; DocumentNo: Code[20]; BuyFromVendorNo: Code[20]; PayToVendorNo: Code[20]; OrderDate: Date; PostingDate: Date; DocumentDate: Date; CurrencyCode: Code[10]; LocationCode: Code[10])
    begin
        Document.Add('documentKind', DocumentKind);
        Document.Add('posted', Posted);
        Document.Add('number', DocumentNo);
        Document.Add('buyFromVendorNo', BuyFromVendorNo);
        Document.Add('payToVendorNo', PayToVendorNo);
        if OrderDate <> 0D then
            Document.Add('orderDate', OrderDate);
        if PostingDate <> 0D then
            Document.Add('postingDate', PostingDate);
        if DocumentDate <> 0D then
            Document.Add('documentDate', DocumentDate);
        Document.Add('currencyCode', CurrencyCode);
        Document.Add('locationCode', LocationCode);
        AddMatchedRoles(DocumentBuffer."Matched Roles", Document);
    end;

    local procedure AddSalesLineFields(var LineObject: JsonObject; LineNo: Integer; LineType: Text; Number: Code[20]; Description: Text; Quantity: Decimal; UnitOfMeasureCode: Code[10]; VariantCode: Code[10]; LocationCode: Code[10]; UnitPrice: Decimal)
    begin
        LineObject.Add('lineNo', LineNo);
        LineObject.Add('type', LineType);
        LineObject.Add('number', Number);
        LineObject.Add('description', Description);
        LineObject.Add('quantity', Quantity);
        LineObject.Add('unitOfMeasureCode', UnitOfMeasureCode);
        LineObject.Add('variantCode', VariantCode);
        LineObject.Add('locationCode', LocationCode);
        LineObject.Add('unitPrice', UnitPrice);
    end;

    local procedure AddPurchaseLineFields(var LineObject: JsonObject; LineNo: Integer; LineType: Text; Number: Code[20]; Description: Text; Quantity: Decimal; UnitOfMeasureCode: Code[10]; VariantCode: Code[10]; LocationCode: Code[10]; DirectUnitCost: Decimal)
    begin
        LineObject.Add('lineNo', LineNo);
        LineObject.Add('type', LineType);
        LineObject.Add('number', Number);
        LineObject.Add('description', Description);
        LineObject.Add('quantity', Quantity);
        LineObject.Add('unitOfMeasureCode', UnitOfMeasureCode);
        LineObject.Add('variantCode', VariantCode);
        LineObject.Add('locationCode', LocationCode);
        LineObject.Add('directUnitCost', DirectUnitCost);
    end;

    local procedure AddMatchedRoles(MatchedRolesText: Text; var Document: JsonObject)
    var
        MatchedRoles: JsonArray;
    begin
        if StrPos(MatchedRolesText, 'sellTo') <> 0 then
            MatchedRoles.Add('sellTo');
        if StrPos(MatchedRolesText, 'billTo') <> 0 then
            MatchedRoles.Add('billTo');
        if StrPos(MatchedRolesText, 'buyFrom') <> 0 then
            MatchedRoles.Add('buyFrom');
        if StrPos(MatchedRolesText, 'payTo') <> 0 then
            MatchedRoles.Add('payTo');
        if MatchedRoles.Count() > 0 then
            Document.Add('matchedRoles', MatchedRoles);
    end;

    local procedure AddMatchingSalesLine(ContextTableId: Integer; CurrentRecordNo: Code[20]; LineType: Enum "Sales Line Type"; Number: Code[20]; LineNo: Integer; var MatchingLineNumbers: JsonArray)
    begin
        if (ContextTableId = Database::Item) and (LineType = LineType::Item) and (Number = CurrentRecordNo) then
            MatchingLineNumbers.Add(LineNo);
    end;

    local procedure AddMatchingPurchaseLine(ContextTableId: Integer; CurrentRecordNo: Code[20]; LineType: Enum "Purchase Line Type"; Number: Code[20]; LineNo: Integer; var MatchingLineNumbers: JsonArray)
    begin
        if (ContextTableId = Database::Item) and (LineType = LineType::Item) and (Number = CurrentRecordNo) then
            MatchingLineNumbers.Add(LineNo);
    end;

    local procedure AddMatchingLines(ContextTableId: Integer; MatchingLineNumbers: JsonArray; var Document: JsonObject)
    begin
        if ContextTableId = Database::Item then
            Document.Add('matchingLineNumbers', MatchingLineNumbers);
    end;
}
