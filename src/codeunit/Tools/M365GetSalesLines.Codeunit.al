codeunit 52002 "M365 Get Sales Lines" implements "AOAI Function"
{
    InherentEntitlements = X;
    InherentPermissions = X;
    Access = Internal;

    var
        FunctionNameLbl: Label 'getSalesLines', Locked = true, Comment = 'The name of the ai function.';
        FunctionDescriptionLbl: Label 'Returns the lines of the current sales document. For every line of type Item call the function getItem with the field no to get the details of the item.', Locked = true;
        NoDocumentErr: Label 'No sales document is available in the current context.', Locked = true;

    procedure GetPrompt(): JsonObject
    var
        aiFunctionBuilder: Codeunit "M365 AI Function Builder";
        function: JsonObject;
        parameters: JsonObject;
        properties: JsonObject;
    begin
        // The document is taken from the context, so the function has no parameters
        parameters.Add('type', 'object');
        parameters.Add('properties', properties);

        function.Add('name', FunctionNameLbl);
        function.Add('description', FunctionDescriptionLbl);
        function.Add('parameters', parameters);

        exit(aiFunctionBuilder.NewTool(Enum::"M365 AI Tool Type"::Function, function));
    end;

    procedure Execute(arguments: JsonObject): Variant
    var
        salesHeader: Record "Sales Header";
    begin
        exit(GetSalesLines(salesHeader));
    end;

    procedure GetName(): Text
    begin
        exit(FunctionNameLbl)
    end;

    local procedure GetSalesLines(salesHeader: Record "Sales Header"): JsonObject
    var
        salesLine: Record "Sales Line";
        lines: JsonArray;
        resultObject: JsonObject;
    begin
        salesLine.SetRange("Document Type", salesHeader."Document Type");
        salesLine.SetRange("Document No.", salesHeader."No.");
        salesLine.SetRange("Type", salesLine.Type::Item);

        if salesLine.FindSet() then
            repeat
                lines.Add(GetSalesLine(salesLine));
            until salesLine.Next() = 0;

        resultObject.Add('documentType', Format(salesHeader."Document Type"));
        resultObject.Add('documentNo', salesHeader."No.");
        resultObject.Add('lines', lines);
        exit(resultObject);
    end;

    local procedure GetSalesLine(salesLine: Record "Sales Line"): JsonObject
    var
        lineObject: JsonObject;
    begin
        lineObject.Add('lineNo', salesLine."Line No.");
        lineObject.Add('type', Format(salesLine.Type));
        lineObject.Add('no', salesLine."No.");
        lineObject.Add('variantCode', salesLine."Variant Code");
        lineObject.Add('description', salesLine.Description);
        lineObject.Add('quantity', salesLine.Quantity);
        lineObject.Add('unitOfMeasureCode', salesLine."Unit of Measure Code");
        lineObject.Add('unitPrice', salesLine."Unit Price");
        lineObject.Add('lineAmount', salesLine."Line Amount");
        lineObject.Add('shipmentDate', salesLine."Shipment Date");
        exit(lineObject);
    end;
}
