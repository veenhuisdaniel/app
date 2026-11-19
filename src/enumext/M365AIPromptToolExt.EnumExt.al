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
    value(52002; GetUnavailableSalesLines)
    {
        Caption = 'Get Unavailable Sales Lines';
        Implementation = System.AI."AOAI Function" = "MCON Get Unavailable Lines";
    }
    value(52003; GetReplacementItemCandidates)
    {
        Caption = 'Get Replacement Item Candidates';
        Implementation = System.AI."AOAI Function" = "MCON Get Replacement Cand.";
    }
}
