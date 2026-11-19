page 52000 "MCON Item Repl. Proposals"
{
    PageType = Worksheet;
    SourceTable = "MCON Item Repl. Result";
    SourceTableTemporary = true;
    SourceTableView = sorting("Entry No.") order(ascending);
    ApplicationArea = All;
    UsageCategory = None;
    Caption = 'Item Replacement Suggestions';
    DataCaptionExpression = Rec."Sales Order No.";
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            group(Analysis)
            {
                Caption = 'Analysis Result';
                field(AnalysisMessage; AnalysisMessage)
                {
                    ShowCaption = false;
                    MultiLine = true;
                    Editable = false;
                    Style = Unfavorable;
                    StyleExpr = HasWarnings;
                    ToolTip = 'Shows missing replacements and the search filters above the list. Only indented rows are replacement candidates.';
                }
            }
            repeater(Candidates)
            {
                ShowAsTree = true;
                IndentationColumn = Rec.Indentation;
                IndentationControls = ItemNo;
                TreeInitialState = ExpandAll;
                field(ItemNo; DisplayItemNo)
                {
                    Caption = 'Item No.';
                    ToolTip = 'Bold parent rows show original items. Indented rows show different replacement items.';
                    StyleExpr = RowStyle;
                }
                field(Description; DisplayDescription)
                {
                    Caption = 'Description';
                    ToolTip = 'Specifies the description of the original item or the replacement candidate on this row.';
                    StyleExpr = RowStyle;
                }
                field(RowKind; RowKind)
                {
                    Caption = 'Row Type';
                    ToolTip = 'Distinguishes original sales lines from replacement candidates and the best AI recommendation.';
                    StyleExpr = RowStyle;
                }
                field(OriginalLineNo; Rec."Original Line No.")
                {
                    Caption = 'Sales Line';
                    ToolTip = 'Specifies the original sales line.';
                }
                field(LocationCode; Rec."Location Code")
                {
                    Caption = 'Location';
                    ToolTip = 'Specifies the location used for the inventory check.';
                }
                field(RequiredQuantity; Rec."Required Quantity")
                {
                    Caption = 'Required Quantity';
                    ToolTip = 'Specifies the outstanding quantity in the sales line unit.';
                }
                field(UnitOfMeasure; Rec."Unit of Measure Code")
                {
                    Caption = 'Unit of Measure';
                    ToolTip = 'Specifies the sales line unit of measure.';
                }
                field(Inventory; DisplayInventory)
                {
                    Caption = 'Inventory (Base)';
                    ToolTip = 'Specifies the current inventory of the item on this row in base units at the original location when analysed.';
                }
                field(Score; Rec."Similarity Score")
                {
                    Caption = 'Similarity (0-1)';
                    BlankZero = true;
                    ToolTip = 'Specifies the AI similarity score. A recommendation needs at least 0.75.';
                }
                field(Reason; Rec."Selection Reason")
                {
                    Caption = 'AI Assessment';
                    ToolTip = 'Specifies the reason for the AI score.';
                }
                field(Applied; Rec.Applied)
                {
                    Caption = 'Replacement Applied';
                    ToolTip = 'Specifies that a replacement has already been applied to this sales line.';
                }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(UseReplacement)
            {
                ApplicationArea = All;
                Caption = 'Use Selected Replacement';
                Image = Change;
                Enabled = CanApply;
                ToolTip = 'Apply the replacement after confirmation. For partially shipped lines, retain the shipped quantity and create a new line for the outstanding quantity. Standard validation recalculates item data and prices.';

                trigger OnAction()
                var
                    TempLineResults: Record "MCON Item Repl. Result" temporary;
                    Workflow: Codeunit "MCON Item Repl. Workflow";
                begin
                    if Workflow.ApplyReplacement(Rec) then begin
                        TempLineResults.Copy(Rec, true);
                        TempLineResults.Reset();
                        TempLineResults.SetRange("Original Sales Line SystemId", Rec."Original Sales Line SystemId");
                        TempLineResults.ModifyAll(Applied, true);
                        CurrPage.Update(false);
                    end;
                end;
            }

        }
        area(Promoted)
        {
            actionref(UseReplacementPromoted; UseReplacement) { }
        }
    }

    trigger OnOpenPage()
    begin
        BuildAnalysisMessage();
    end;

    trigger OnAfterGetRecord()
    begin
        if Rec."Is Original" then begin
            DisplayItemNo := Rec."Original Item No.";
            DisplayDescription := Rec."Original Item Description";
            DisplayInventory := Rec."Current Inventory Base";
            RowKind := OriginalRowLbl;
            RowStyle := 'Strong';
        end else begin
            DisplayItemNo := Rec."Replacement Item No.";
            DisplayDescription := Rec."Replacement Item Description";
            DisplayInventory := Rec."Replacement Inv. Base";
            RowKind := CandidateRowLbl;
            RowStyle := 'Standard';
            if Rec.Recommended then begin
                RowKind := RecommendedRowLbl;
                RowStyle := 'Favorable';
            end;
        end;
    end;

    trigger OnAfterGetCurrRecord()
    begin
        CanApply := not Rec."Is Original" and not Rec.Applied and
            (Rec."Replacement Item No." <> '') and (Rec."Validation Status" = 'ASSESSED');
    end;

    var
        AnalysisMessage: Text;
        DisplayItemNo: Code[20];
        DisplayDescription: Text[100];
        DisplayInventory: Decimal;
        RowKind: Text;
        RowStyle: Text;
        HasWarnings: Boolean;
        CanApply: Boolean;
        OriginalRowLbl: Label 'Original - insufficient stock';
        CandidateRowLbl: Label 'Replacement candidate';
        RecommendedRowLbl: Label 'Best AI recommendation';
        InstructionsLbl: Label 'Original sales lines are bold. Replacement candidates are shown as separate indented rows. Select a replacement row to use it; the original item is never a replacement candidate.';
        MissingReplacementLbl: Label 'NO SUITABLE REPLACEMENT for one or more sales lines:';
        LineResultLbl: Label 'Sales line %1, original item %2: %3', Comment = '%1 = line number, %2 = original item number, %3 = no-match reason';

    local procedure BuildAnalysisMessage()
    var
        TempOriginals: Record "MCON Item Repl. Result" temporary;
        MessageBuilder: TextBuilder;
    begin
        TempOriginals.Copy(Rec, true);
        TempOriginals.Reset();
        TempOriginals.SetRange("Is Original", true);
        HasWarnings := false;
        if TempOriginals.FindSet() then
            repeat
                if TempOriginals."Result Reason" <> '' then begin
                    if not HasWarnings then
                        MessageBuilder.AppendLine(MissingReplacementLbl);
                    HasWarnings := true;
                    MessageBuilder.AppendLine(StrSubstNo(
                        LineResultLbl, TempOriginals."Original Line No.", TempOriginals."Original Item No.", TempOriginals."Result Reason"));
                    if TempOriginals."Search Diagnostics" <> '' then
                        MessageBuilder.AppendLine(TempOriginals."Search Diagnostics");
                end;
            until TempOriginals.Next() = 0;
        if HasWarnings then
            MessageBuilder.AppendLine();
        MessageBuilder.AppendLine(InstructionsLbl);
        AnalysisMessage := MessageBuilder.ToText();
    end;
}
