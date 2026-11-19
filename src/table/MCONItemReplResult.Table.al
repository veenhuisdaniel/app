table 52000 "MCON Item Repl. Result"
{
    TableType = Temporary;
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            AutoIncrement = true;
        }
        field(2; "Sales Order No."; Code[20]) { }
        field(3; "Original Sales Line SystemId"; Guid) { }
        field(4; "Original Line No."; Integer) { }
        field(5; "Original Item No."; Code[20]) { }
        field(6; "Original Item Description"; Text[100]) { }
        field(7; "Current Inventory Base"; Decimal) { }
        field(8; "Required Quantity"; Decimal) { }
        field(9; "Required Quantity Base"; Decimal) { }
        field(10; "Replacement Required"; Boolean) { }
        field(11; Action; Code[40]) { }
        field(12; "Replacement Item No."; Code[20]) { }
        field(13; "Replacement Item Description"; Text[100]) { }
        field(14; "Replacement Inv. Base"; Decimal) { }
        field(15; "Proposed Quantity"; Decimal) { }
        field(16; "Proposed Quantity Base"; Decimal) { }
        field(17; "Similarity Score"; Decimal) { }
        field(18; "Selection Reason"; Text[250]) { }
        field(19; "Reason Code"; Code[50]) { }
        field(20; "Result Reason"; Text[250]) { }
        field(21; "Evaluated Candidate Count"; Integer) { }
        field(22; "Validation Status"; Code[10]) { }
        field(23; "Validation Message"; Text[250]) { }
        field(24; Recommended; Boolean) { }
        field(25; Applied; Boolean) { }
        field(26; "Source Modified At"; DateTime) { }
        field(27; "Location Code"; Code[10]) { }
        field(28; "Unit of Measure Code"; Code[10]) { }
        field(29; "Is Original"; Boolean) { }
        field(30; Indentation; Integer) { }
        field(31; "Search Diagnostics"; Text[1024]) { }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(Ranking; "Original Line No.", Recommended, "Similarity Score", "Replacement Item No.") { }
    }
}
