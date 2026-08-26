pageextension 50114 "Item Card WebMCP" extends "Item Card"
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
