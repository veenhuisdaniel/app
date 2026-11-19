codeunit 52007 "MCON Get Unavailable Lines" implements "AOAI Function"
{
    Access = Internal;

    var
        FunctionNameLbl: Label 'getUnavailableSalesLines', Locked = true;
        FunctionDescriptionLbl: Label 'Returns eligible item sales order lines and marks whether current inventory at the line location is insufficient for the outstanding base quantity. Uses current inventory only; does not include future supply or subtract reservations.', Locked = true;
        MissingArgumentErr: Label 'The required salesOrderNo argument is missing.';

    procedure GetPrompt(): JsonObject
    var
        AIFunctionBuilder: Codeunit "M365 AI Function Builder";
        Parameters: JsonArray;
        FunctionObject: JsonObject;
    begin
        Parameters.Add(AIFunctionBuilder.NewParameter(
            'salesOrderNo', Enum::"M365 AI Parameter Type"::String, 'Sales order number', 20));
        FunctionObject := AIFunctionBuilder.NewFunction(
            FunctionNameLbl, FunctionDescriptionLbl, true, Parameters);
        exit(AIFunctionBuilder.NewTool(Enum::"M365 AI Tool Type"::Function, FunctionObject));
    end;

    procedure Execute(Arguments: JsonObject): Variant
    var
        ContextMgt: Codeunit "MCON Item Repl. Context Mgt.";
        ArgumentToken: JsonToken;
        SalesOrderNo: Code[20];
    begin
        if not Arguments.Get('salesOrderNo', ArgumentToken) then
            Error(MissingArgumentErr);

        SalesOrderNo := CopyStr(ArgumentToken.AsValue().AsText(), 1, MaxStrLen(SalesOrderNo));
        exit(ContextMgt.GetSalesOrderContext(SalesOrderNo));
    end;

    procedure GetName(): Text
    begin
        exit(FunctionNameLbl);
    end;
}
