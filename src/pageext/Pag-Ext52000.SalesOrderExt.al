pageextension 52000 "Sales Order Ext" extends "Sales Order"
{
    actions
    {

        addlast(Prompting)
        {
            action("KIAgentCall")
            {
                ApplicationArea = All;
                Caption = 'KI Agent Call', locked = true;
                Image = Sparkle;

                trigger OnAction()
                var
                begin
                    CallKIAgent();
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