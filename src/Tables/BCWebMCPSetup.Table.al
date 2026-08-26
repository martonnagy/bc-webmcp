table 50102 "BC WebMCP Setup"
{
    Caption = 'BC WebMCP Setup';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
        }
        field(10; "Default Ledger Entry Count"; Integer)
        {
            Caption = 'Default Ledger Entry Count';
            DataClassification = SystemMetadata;
            MinValue = 1;

            trigger OnValidate()
            begin
                if ("Maximum Ledger Entry Count" <> 0) and ("Default Ledger Entry Count" > "Maximum Ledger Entry Count") then
                    Error(DefaultExceedsMaximumErr, FieldCaption("Default Ledger Entry Count"), FieldCaption("Maximum Ledger Entry Count"));
            end;
        }
        field(11; "Maximum Ledger Entry Count"; Integer)
        {
            Caption = 'Maximum Ledger Entry Count';
            DataClassification = SystemMetadata;
            MinValue = 1;

            trigger OnValidate()
            begin
                if ("Default Ledger Entry Count" <> 0) and ("Maximum Ledger Entry Count" < "Default Ledger Entry Count") then
                    Error(MaximumBelowDefaultErr, FieldCaption("Maximum Ledger Entry Count"), FieldCaption("Default Ledger Entry Count"));
            end;
        }
        field(20; "Default Document Count"; Integer)
        {
            Caption = 'Default Document Count';
            DataClassification = SystemMetadata;
            MinValue = 1;

            trigger OnValidate()
            begin
                if ("Maximum Document Count" <> 0) and ("Default Document Count" > "Maximum Document Count") then
                    Error(DefaultExceedsMaximumErr, FieldCaption("Default Document Count"), FieldCaption("Maximum Document Count"));
            end;
        }
        field(21; "Maximum Document Count"; Integer)
        {
            Caption = 'Maximum Document Count';
            DataClassification = SystemMetadata;
            MinValue = 1;

            trigger OnValidate()
            begin
                if ("Default Document Count" <> 0) and ("Maximum Document Count" < "Default Document Count") then
                    Error(MaximumBelowDefaultErr, FieldCaption("Maximum Document Count"), FieldCaption("Default Document Count"));
            end;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    var
        DefaultExceedsMaximumErr: Label '%1 cannot exceed %2.';
        MaximumBelowDefaultErr: Label '%1 cannot be lower than %2.';
}
