codeunit 52002 "M365 Return Order Processes" implements "AOAI Function"
{

    InherentEntitlements = X;
    InherentPermissions = X;
    Access = Internal;

    var
        FunctionNameLbl: Label 'getItem', Locked = true, Comment = 'The name of the ai function.';

    procedure GetPrompt(): JsonObject
    var
        aiFunctionBuilder: Codeunit "M365 AI Function Builder";
        parameters: JsonArray;
        function: JsonObject;
        tool: JsonObject;
    begin
        parameters.Add(aiFunctionBuilder.NewParameter('itemNo', Enum::"M365 AI Parameter Type"::String, 'The No. of the item', 20));
        function := aiFunctionBuilder.NewFunction(FunctionNameLbl, 'Returns the details of the specified item no.', true, parameters);
        tool := aiFunctionBuilder.NewTool(Enum::"M365 AI Tool Type"::Function, function);

        exit(tool);
    end;

    procedure Execute(arguments: JsonObject): Variant
    var
        itemNo: JsonToken;
    begin
        arguments.Get('itemNo', itemNo);

        exit(GetItem(CopyStr(itemNo.AsValue().AsCode(), 1, 20)));
    end;

    procedure GetName(): Text
    begin
        exit(FunctionNameLbl)
    end;

    local procedure GetItem(itemNo: Code[20]): JsonObject
    var
        item: Record Item;
        jsonHelper: Codeunit "M365 Json Helper";
        tempRecRef: RecordRef;
        resultObject: JsonObject;
    begin
        item.Get(itemNo);

        tempRecRef.GetTable(item);
        jsonHelper.MapRecordToObject(tempRecRef, resultObject);

        exit(resultObject);
    end;
}