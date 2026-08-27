pageextension 50121 "Customer List WebMCP" extends "Customer List"
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
        CurrPage.BCWebMCP.Page.SetListContext(Database::Customer, Rec.GetView(false));
    end;
}
