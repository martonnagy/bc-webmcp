pageextension 50122 "Vendor List WebMCP" extends "Vendor List"
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
        CurrPage.BCWebMCP.Page.SetListContext(Database::Vendor, Rec.GetView(false));
    end;
}
