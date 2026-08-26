table 50120 "BC WebMCP Document Buffer"
{
    TableType = Temporary;
    Access = Internal;
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            DataClassification = SystemMetadata;
        }
        field(2; "Sort Date"; Date)
        {
            DataClassification = SystemMetadata;
        }
        field(3; "Document No."; Code[20])
        {
            DataClassification = SystemMetadata;
        }
        field(4; "Header Record ID"; RecordId)
        {
            DataClassification = SystemMetadata;
        }
        field(5; "Header Table ID"; Integer)
        {
            DataClassification = SystemMetadata;
        }
        field(6; "Matched Roles"; Text[100])
        {
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(Sort; "Sort Date", "Document No.")
        {
        }
    }
}
