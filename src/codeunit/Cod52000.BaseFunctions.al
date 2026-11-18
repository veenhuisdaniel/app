codeunit 52000 "Base Functions"
implements "M365 AI Operation"
{
    procedure ShowPromptDialog(aiPrompt: Record "M365 AI Prompt"; recordVariant: Variant): Boolean
    begin
    end;

    procedure Execute(aiPrompt: Record "M365 AI Prompt"; recordVariant: Variant; var aiInteraction: Record "M365 AI Interaction"): Boolean
    begin
    end;

    procedure Execute(aiPrompt: Record "M365 AI Prompt"; recordVariant: Variant; var aiInteraction: Record "M365 AI Interaction"; var resultVariant: Variant): Boolean
    begin
    end;

    procedure GetResult(var resultRecRef: RecordRef): Boolean
    begin
    end;

    procedure GetResult(var result: Text): Boolean
    begin
    end;
}
