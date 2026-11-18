pageextension 52001 "Sales & Receivables Setup Ext" extends "Sales & Receivables Setup"
{
    layout
    {
        addlast(M365)
        {
            field("AI Prompt"; Rec."AI Prompt")
            {
                ApplicationArea = All;
                Tooltip = 'Select an AI Prompt, which is used for AI-driven processes in the system.';
            }
        }
    }
}
