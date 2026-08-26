page 50103 "BC WebMCP Setup"
{
    PageType = Card;
    SourceTable = "BC WebMCP Setup";
    ApplicationArea = All;
    Caption = 'BC WebMCP Setup';
    UsageCategory = Administration;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(LedgerEntries)
            {
                Caption = 'Ledger Entries';
                field(DefaultLedgerEntryCount; Rec."Default Ledger Entry Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of ledger entries returned when a tool call does not supply count.';
                }
                field(MaximumLedgerEntryCount; Rec."Maximum Ledger Entry Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the largest number of ledger entries a tool call can retrieve.';
                }
            }
            group(Documents)
            {
                Caption = 'Documents';
                field(DefaultDocumentCount; Rec."Default Document Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of documents returned when a tool call does not supply count.';
                }
                field(MaximumDocumentCount; Rec."Maximum Document Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the largest number of document headers a tool call can retrieve.';
                }
            }
        }
    }

    trigger OnOpenPage()
    var
        Management: Codeunit "BC WebMCP Management";
    begin
        Management.EnsureSetup();
        Rec.Get();
    end;
}
