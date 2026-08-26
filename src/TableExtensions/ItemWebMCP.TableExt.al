tableextension 50112 "Item WebMCP" extends Item
{
    fields
    {
        field(50100; "Last Accessed by WebMCP"; DateTime)
        {
            Caption = 'Last Accessed by WebMCP';
            DataClassification = SystemMetadata;
            Editable = false;
        }
    }
}
