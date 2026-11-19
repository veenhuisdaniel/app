permissionset 52000 "MCON ITEM REPL"
{
    Assignable = true;
    Caption = 'MCON Item Replacement';

    Permissions =
        tabledata "Sales Header" = R,
        tabledata "Sales Line" = RIM,
        tabledata "Sales & Receivables Setup" = R,
        tabledata Item = R,
        tabledata "Item Unit of Measure" = R,
        tabledata "Item Ledger Entry" = R,
        tabledata "Item Attribute" = R,
        tabledata "Item Attribute Translation" = R,
        tabledata "Item Attribute Value" = R,
        tabledata "Item Attribute Value Mapping" = R,
        tabledata "Reservation Entry" = R,
        tabledata "MCON Item Repl. Result" = RIMD,
        table "MCON Item Repl. Result" = X,
        codeunit "MCON Item Attribute Mgt." = X,
        codeunit "MCON Item Repl. Context Mgt." = X,
        codeunit "MCON Item Repl. Cand. Mgt." = X,
        codeunit "MCON Item Repl. Result Mgt." = X,
        codeunit "MCON Item Repl. Workflow" = X,
        codeunit "MCON Get Unavailable Lines" = X,
        codeunit "MCON Get Replacement Cand." = X,
        page "MCON Item Repl. Proposals" = X;
}
