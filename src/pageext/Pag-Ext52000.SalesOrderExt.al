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
        aiInterAction: CodeUnit "M365 AI Interaction";
        additionalTextsToProcess: Dictionary of [Text, Text];
        returnExternalAnswer, returnInternalAnswer : Text;
    begin
        newAIPrompt.Get('TEST_DVE'); // Im Projekt Einrichtungsfeld  schaffen
        aiInterAction.Initialize(Rec, Enum::"Copilot Capability"::M365MagicChatCompletions, newAIPrompt, additionalTextsToProcess);
        aiInterAction.FillInteraction();
        aiInterAction.Send(returnExternalAnswer, returnInternalAnswer);

        Message('External Answer: %1\nInternal Answer: %2', returnExternalAnswer, returnInternalAnswer);
    end;
}