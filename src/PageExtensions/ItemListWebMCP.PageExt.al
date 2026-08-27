pageextension 50123 "Item List WebMCP" extends "Item List"
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
        CurrPage.BCWebMCP.Page.SetListContext(Database::Item, Rec.GetView(false));
    end;
}
