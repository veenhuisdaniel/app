pageextension 52000 "Sales Order Ext" extends "Sales Order"
{
    actions
    {

        addlast(Prompting)
        {
            action("Find Item Replacements")
            {
                ApplicationArea = All;
                Caption = 'Find Item Replacements';
                Image = Sparkle;
                ToolTip = 'Find available replacements for item lines with insufficient stock, let AI assess them, and choose whether to replace an original item.';

                trigger OnAction()
                var
                    TempReplacementContext: Record "MCON Item Repl. Result" temporary;
                    Workflow: Codeunit "MCON Item Repl. Workflow";
                    NoShortageLbl: Label 'No item lines with insufficient current inventory were found.';
                begin
                    CurrPage.SaveRecord();
                    Commit();
                    if not Workflow.Generate(Rec."No.", TempReplacementContext) then begin
                        Message(NoShortageLbl);
                        exit;
                    end;
                    TempReplacementContext.FindFirst();
                    // AI processing can start a write transaction; the modal page must open outside it.
                    Commit();
                    Page.RunModal(Page::"MCON Item Repl. Proposals", TempReplacementContext);
                    CurrPage.Update(false);
                end;
            }
        }
    }

    procedure CallKIAgent()
    var
        newAIPrompt: Record "M365 AI Prompt";
        salesReceivableSetup: Record "Sales & Receivables Setup";
        aiInterAction: CodeUnit "M365 AI Interaction";
        additionalTextsToProcess: Dictionary of [Text, Text];
        returnExternalAnswer, returnInternalAnswer : Text;
    begin
        salesReceivableSetup.Get();
        salesReceivableSetup.TestField("AI Prompt");

        newAIPrompt.Get(salesReceivableSetup."AI Prompt");
        aiInterAction.Initialize(Rec, Enum::"Copilot Capability"::M365MagicChatCompletions, newAIPrompt, additionalTextsToProcess);
        // Loads the order data via the data entity, so placeholders and structured data reach the AI
        aiInterAction.PopulateDataObjects();
        aiInterAction.FillInteraction();
        aiInterAction.Send(returnExternalAnswer, returnInternalAnswer);


        Message('External Answer: %1\nInternal Answer: %2', returnExternalAnswer, returnInternalAnswer);
    end;

}