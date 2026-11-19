enumextension 52000 "M365 AI Prompt Tool Ext" extends "M365 AI Prompt Tool"
{
    value(52001; GetSalesLines)
    {
        Caption = 'Get Sales Lines';
        Implementation = System.AI."AOAI Function" = "M365 Get Sales Lines";
    }
    value(52000; GetItem)
    {
        Caption = 'Get Item';
        Implementation = System.AI."AOAI Function" = "M365 Get Item";
    }
}
