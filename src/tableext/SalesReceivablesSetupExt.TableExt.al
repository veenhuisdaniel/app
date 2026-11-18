tableextension 52000 "Sales & Receivables Setup Ext" extends "Sales & Receivables Setup"
{
    fields
    {
        field(52000; "AI Prompt"; Code[20])
        {
            Caption = 'AI Prompt';
            DataClassification = CustomerContent;
            TableRelation = "M365 AI Prompt";
        }
    }
}
