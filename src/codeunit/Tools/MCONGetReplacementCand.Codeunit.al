codeunit 52008 "MCON Get Replacement Cand." implements "AOAI Function"
{
    Access = Internal;

    var
        FunctionNameLbl: Label 'getReplacementItemCandidates', Locked = true;
        FunctionDescriptionLbl: Label 'Returns eligible replacement items for one sales order line. Candidates have the same item category and sales unit, are not blocked, and have sufficient current inventory at the line location. Retrieve all pages before recommending.', Locked = true;
        MissingArgumentErr: Label 'A required argument is missing: %1.', Comment = '%1 = Argument name';
        InvalidSystemIdErr: Label 'The originalSalesLineSystemId argument must be a GUID.';

    procedure GetPrompt(): JsonObject
    var
        AIFunctionBuilder: Codeunit "M365 AI Function Builder";
        Parameters: JsonArray;
        FunctionObject: JsonObject;
    begin
        Parameters.Add(AIFunctionBuilder.NewParameter(
            'originalSalesLineSystemId', Enum::"M365 AI Parameter Type"::String, 'SystemId of the original sales line', 36));
        Parameters.Add(AIFunctionBuilder.NewParameter(
            'pageNumber', Enum::"M365 AI Parameter Type"::Integer, 'Page number starting at 1', 0));
        Parameters.Add(AIFunctionBuilder.NewParameter(
            'pageSize', Enum::"M365 AI Parameter Type"::Integer, 'Page size from 1 through 100', 0));
        FunctionObject := AIFunctionBuilder.NewFunction(
            FunctionNameLbl, FunctionDescriptionLbl, true, Parameters);
        exit(AIFunctionBuilder.NewTool(Enum::"M365 AI Tool Type"::Function, FunctionObject));
    end;

    procedure Execute(Arguments: JsonObject): Variant
    var
        CandidateMgt: Codeunit "MCON Item Repl. Cand. Mgt.";
        ArgumentToken: JsonToken;
        OriginalSalesLineSystemId: Guid;
        PageNumber: Integer;
        PageSize: Integer;
        SystemIdText: Text;
    begin
        if not Arguments.Get('originalSalesLineSystemId', ArgumentToken) then
            Error(MissingArgumentErr, 'originalSalesLineSystemId');
        SystemIdText := ArgumentToken.AsValue().AsText();
        if not Evaluate(OriginalSalesLineSystemId, SystemIdText) then
            Error(InvalidSystemIdErr);

        if not Arguments.Get('pageNumber', ArgumentToken) then
            Error(MissingArgumentErr, 'pageNumber');
        PageNumber := ArgumentToken.AsValue().AsInteger();

        if not Arguments.Get('pageSize', ArgumentToken) then
            Error(MissingArgumentErr, 'pageSize');
        PageSize := ArgumentToken.AsValue().AsInteger();

        exit(CandidateMgt.GetCandidates(OriginalSalesLineSystemId, PageNumber, PageSize));
    end;

    procedure GetName(): Text
    begin
        exit(FunctionNameLbl);
    end;
}
