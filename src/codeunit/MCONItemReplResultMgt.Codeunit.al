codeunit 52009 "MCON Item Repl. Result Mgt."
{
    var
        InvalidJsonErr: Label 'The agent response is not valid JSON.';
        InvalidResponseErr: Label 'The agent response is invalid: %1', Comment = '%1 = validation detail';
        MissingOrderErr: Label 'The response must contain salesOrderNo with the requested order number %1.', Comment = '%1 = expected sales order number';
        MismatchedOrderErr: Label 'The response contains salesOrderNo "%1", but the requested order number is "%2".', Comment = '%1 = returned sales order number, %2 = expected sales order number';
        OrderNotFoundErr: Label 'Sales order %1 no longer exists.', Comment = '%1 = expected sales order number';
        AgentErrorErr: Label 'The agent reported an error: %1', Comment = '%1 = error returned in the JSON response';
        InvalidCalculationErr: Label 'inventoryCalculation must be CURRENT_INVENTORY.';
        InvalidSchemaErr: Label 'schemaVersion must be 1.0.';
        MissingRecommendationsErr: Label 'recommendations must be a JSON array.';
        InvalidRecommendationErr: Label 'A recommendation is malformed or refers to an invalid sales line.';
        DuplicateRecommendationErr: Label 'More than one recommendation was returned for the same sales line.';
        InvalidActionErr: Label 'The recommendation contains an unsupported action or reasonCode.';
        InvalidReplacementErr: Label 'The replacement item is not a current eligible candidate or the recommendation quantities are stale.';
        InvalidScoreErr: Label 'A replacement recommendation must have a similarityScore from 0.75 through 1.';
        InvalidCandidateCountErr: Label 'evaluatedCandidateCount cannot be negative.';
        NoActionInventorySufficientLbl: Label 'NO_ACTION_INVENTORY_SUFFICIENT', Locked = true;
        RecommendReplacementLbl: Label 'RECOMMEND_REPLACEMENT', Locked = true;
        NoReplacementFoundLbl: Label 'NO_REPLACEMENT_FOUND', Locked = true;
        ErrorActionLbl: Label 'ERROR', Locked = true;
        InventorySufficientLbl: Label 'INVENTORY_SUFFICIENT', Locked = true;
        MatchFoundLbl: Label 'MATCH_FOUND', Locked = true;
        NoCandidatesLbl: Label 'NO_CANDIDATES', Locked = true;
        InsufficientCandidateInventoryLbl: Label 'INSUFFICIENT_CANDIDATE_INVENTORY', Locked = true;
        SimilarityBelowThresholdLbl: Label 'SIMILARITY_BELOW_THRESHOLD', Locked = true;
        CriticalAttributeConflictLbl: Label 'CRITICAL_ATTRIBUTE_CONFLICT', Locked = true;
        InsufficientProductInformationLbl: Label 'INSUFFICIENT_PRODUCT_INFORMATION', Locked = true;
        IncompleteCandidateRetrievalLbl: Label 'INCOMPLETE_CANDIDATE_RETRIEVAL', Locked = true;
        ToolErrorLbl: Label 'TOOL_ERROR', Locked = true;

    procedure ParseRecommendationJson(JsonText: Text; var RecommendationObject: JsonObject): Boolean
    begin
        Clear(RecommendationObject);
        exit(RecommendationObject.ReadFrom(JsonText));
    end;

    procedure ValidateRecommendationJson(JsonText: Text; ExpectedSalesOrderNo: Code[20]; var ErrorMessage: Text): Boolean
    var
        RecommendationObject: JsonObject;
    begin
        Clear(ErrorMessage);
        if not ParseRecommendationJson(JsonText, RecommendationObject) then begin
            ErrorMessage := InvalidJsonErr;
            exit(false);
        end;

        exit(ValidateRecommendationObject(RecommendationObject, ExpectedSalesOrderNo, ErrorMessage));
    end;

    procedure ImportRecommendationsToTemporaryBuffer(
        JsonText: Text;
        ExpectedSalesOrderNo: Code[20];
        var TempResult: Record "MCON Item Repl. Result" temporary)
    var
        RecommendationObject: JsonObject;
        RecommendationToken: JsonToken;
        Recommendations: JsonArray;
        Recommendation: JsonObject;
        ErrorMessage: Text;
        Index: Integer;
    begin
        if not ParseRecommendationJson(JsonText, RecommendationObject) then
            Error(InvalidJsonErr);
        if not ValidateRecommendationObject(RecommendationObject, ExpectedSalesOrderNo, ErrorMessage) then
            Error(InvalidResponseErr, ErrorMessage);

        RecommendationObject.Get('recommendations', RecommendationToken);
        Recommendations := RecommendationToken.AsArray();
        TempResult.Reset();
        TempResult.DeleteAll();
        for Index := 0 to Recommendations.Count() - 1 do begin
            Recommendations.Get(Index, RecommendationToken);
            Recommendation := RecommendationToken.AsObject();
            ImportRecommendation(Recommendation, ExpectedSalesOrderNo, TempResult);
        end;
    end;

    local procedure ValidateRecommendationObject(RecommendationObject: JsonObject; ExpectedSalesOrderNo: Code[20]; var ErrorMessage: Text): Boolean
    var
        SalesHeader: Record "Sales Header";
        RecommendationToken: JsonToken;
        Recommendations: JsonArray;
        SeenSalesLines: Dictionary of [Guid, Boolean];
        ActualSalesOrderNo: Text;
        AgentError: Text;
        HasAgentError: Boolean;
        Index: Integer;
    begin
        if not HasTextValue(RecommendationObject, 'schemaVersion', '1.0') then
            exit(SetError(ErrorMessage, InvalidSchemaErr));
        if not TryGetText(RecommendationObject, 'salesOrderNo', ActualSalesOrderNo) or (ActualSalesOrderNo = '') then
            exit(SetError(ErrorMessage, StrSubstNo(MissingOrderErr, ExpectedSalesOrderNo)));
        if ActualSalesOrderNo <> ExpectedSalesOrderNo then
            exit(SetError(ErrorMessage, StrSubstNo(MismatchedOrderErr, ActualSalesOrderNo, ExpectedSalesOrderNo)));
        if not SalesHeader.Get(SalesHeader."Document Type"::Order, ExpectedSalesOrderNo) then
            exit(SetError(ErrorMessage, StrSubstNo(OrderNotFoundErr, ExpectedSalesOrderNo)));
        if RecommendationObject.Get('error', RecommendationToken) then begin
            HasAgentError := true;
            if RecommendationToken.IsValue() then
                HasAgentError := not RecommendationToken.AsValue().IsNull();
            if HasAgentError then begin
                RecommendationToken.WriteTo(AgentError);
                exit(SetError(ErrorMessage, StrSubstNo(AgentErrorErr, AgentError)));
            end;
        end;
        if not HasTextValue(RecommendationObject, 'inventoryCalculation', 'CURRENT_INVENTORY') then
            exit(SetError(ErrorMessage, InvalidCalculationErr));
        if not RecommendationObject.Get('recommendations', RecommendationToken) then
            exit(SetError(ErrorMessage, MissingRecommendationsErr));
        if not RecommendationToken.IsArray() then
            exit(SetError(ErrorMessage, MissingRecommendationsErr));

        Recommendations := RecommendationToken.AsArray();
        for Index := 0 to Recommendations.Count() - 1 do begin
            Recommendations.Get(Index, RecommendationToken);
            if not RecommendationToken.IsObject() then
                exit(SetError(ErrorMessage, InvalidRecommendationErr));
            if not ValidateOneRecommendation(RecommendationToken.AsObject(), ExpectedSalesOrderNo, SeenSalesLines, ErrorMessage) then
                exit(false);
        end;

        exit(true);
    end;

    local procedure ValidateOneRecommendation(Recommendation: JsonObject; ExpectedSalesOrderNo: Code[20]; var SeenSalesLines: Dictionary of [Guid, Boolean]; var ErrorMessage: Text): Boolean
    var
        SalesLine: Record "Sales Line";
        CandidateMgt: Codeunit "MCON Item Repl. Cand. Mgt.";
        Token: JsonToken;
        OriginalSalesLineSystemId: Guid;
        OriginalItemNo: Code[20];
        ActionCode: Text;
        ReasonCode: Text;
        ReplacementObject: JsonObject;
        ReplacementToken: JsonToken;
        ReplacementItemNo: Code[20];
        SimilarityScore: Decimal;
        ProposedQuantity: Decimal;
        ProposedQuantityBase: Decimal;
        EvaluatedCandidateCount: Integer;
    begin
        if not TryGetText(Recommendation, 'originalSalesLineSystemId', ActionCode) then
            exit(SetError(ErrorMessage, InvalidRecommendationErr));
        if not Evaluate(OriginalSalesLineSystemId, ActionCode) then
            exit(SetError(ErrorMessage, InvalidRecommendationErr));
        if SeenSalesLines.ContainsKey(OriginalSalesLineSystemId) then
            exit(SetError(ErrorMessage, DuplicateRecommendationErr));
        SeenSalesLines.Add(OriginalSalesLineSystemId, true);

        SalesLine.SetRange(SystemId, OriginalSalesLineSystemId);
        if not SalesLine.FindFirst() then
            exit(SetError(ErrorMessage, InvalidRecommendationErr));
        if (SalesLine."Document Type" <> SalesLine."Document Type"::Order) or
           (SalesLine."Document No." <> ExpectedSalesOrderNo) or
           (SalesLine.Type <> SalesLine.Type::Item) or
           (SalesLine."No." = '')
        then
            exit(SetError(ErrorMessage, InvalidRecommendationErr));

        if not TryGetText(Recommendation, 'originalItemNo', ActionCode) then
            exit(SetError(ErrorMessage, InvalidRecommendationErr));
        OriginalItemNo := CopyStr(ActionCode, 1, MaxStrLen(OriginalItemNo));
        if SalesLine."No." <> OriginalItemNo then
            exit(SetError(ErrorMessage, InvalidRecommendationErr));

        if not TryGetText(Recommendation, 'action', ActionCode) or
           not TryGetText(Recommendation, 'reasonCode', ReasonCode)
        then
            exit(SetError(ErrorMessage, InvalidActionErr));
        if not IsAllowedAction(ActionCode) or not IsAllowedReasonCode(ReasonCode) then
            exit(SetError(ErrorMessage, InvalidActionErr));

        if not TryGetInteger(Recommendation, 'evaluatedCandidateCount', EvaluatedCandidateCount) or
           (EvaluatedCandidateCount < 0)
        then
            exit(SetError(ErrorMessage, InvalidCandidateCountErr));

        if ActionCode <> RecommendReplacementLbl then
            exit(true);

        if not Recommendation.Get('replacementItem', ReplacementToken) or not ReplacementToken.IsObject() then
            exit(SetError(ErrorMessage, InvalidReplacementErr));
        ReplacementObject := ReplacementToken.AsObject();
        if not TryGetText(ReplacementObject, 'itemNo', ActionCode) then
            exit(SetError(ErrorMessage, InvalidReplacementErr));
        ReplacementItemNo := CopyStr(ActionCode, 1, MaxStrLen(ReplacementItemNo));
        if not TryGetDecimal(ReplacementObject, 'similarityScore', SimilarityScore) or
           (SimilarityScore < 0.75) or (SimilarityScore > 1)
        then
            exit(SetError(ErrorMessage, InvalidScoreErr));

        if not TryGetDecimal(ReplacementObject, 'proposedQuantity', ProposedQuantity) or
           not TryGetDecimal(ReplacementObject, 'proposedQuantityBase', ProposedQuantityBase)
        then
            exit(SetError(ErrorMessage, InvalidReplacementErr));
        if (ProposedQuantity <> SalesLine."Outstanding Quantity") or
           (ProposedQuantityBase <> SalesLine."Outstanding Qty. (Base)") or
           (SalesLine."Outstanding Quantity" <= 0) or
           (SalesLine."Outstanding Qty. (Base)" <= 0) or
           (not CandidateMgt.IsEligibleCandidate(SalesLine, ReplacementItemNo))
        then
            exit(SetError(ErrorMessage, InvalidReplacementErr));

        if not TryGetText(Recommendation, 'originalItemNo', ActionCode) then
            exit(SetError(ErrorMessage, InvalidRecommendationErr));
        if ReplacementItemNo = CopyStr(ActionCode, 1, MaxStrLen(OriginalItemNo)) then
            exit(SetError(ErrorMessage, InvalidReplacementErr));

        if Recommendation.Get('replacementItem', Token) then begin
            if not TryGetText(Token.AsObject(), 'description', ActionCode) then
                exit(SetError(ErrorMessage, InvalidReplacementErr));
        end;
        exit(true);
    end;

    local procedure ImportRecommendation(Recommendation: JsonObject; SalesOrderNo: Code[20]; var TempResult: Record "MCON Item Repl. Result" temporary)
    var
        SalesLine: Record "Sales Line";
        Item: Record Item;
        Token: JsonToken;
        ReplacementObject: JsonObject;
        ActionCode: Text;
        TextValue: Text;
        OriginalSalesLineSystemId: Guid;
    begin
        Recommendation.Get('originalSalesLineSystemId', Token);
        Evaluate(OriginalSalesLineSystemId, Token.AsValue().AsText());
        SalesLine.SetRange(SystemId, OriginalSalesLineSystemId);
        SalesLine.FindFirst();
        Item.Get(SalesLine."No.");

        TempResult.Init();
        TempResult."Sales Order No." := SalesOrderNo;
        TempResult."Original Sales Line SystemId" := OriginalSalesLineSystemId;
        TempResult."Original Line No." := SalesLine."Line No.";
        TempResult."Original Item No." := SalesLine."No.";
        TempResult."Original Item Description" := Item.Description;
        TempResult."Current Inventory Base" := GetCurrentInventoryBase(SalesLine);
        TempResult."Required Quantity" := SalesLine."Outstanding Quantity";
        TempResult."Required Quantity Base" := SalesLine."Outstanding Qty. (Base)";
        TempResult."Replacement Required" :=
            TempResult."Current Inventory Base" < TempResult."Required Quantity Base";
        Recommendation.Get('action', Token);
        TempResult.Action := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(TempResult.Action));
        Recommendation.Get('reasonCode', Token);
        TempResult."Reason Code" := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(TempResult."Reason Code"));
        Recommendation.Get('reason', Token);
        TempResult."Result Reason" := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(TempResult."Result Reason"));
        Recommendation.Get('evaluatedCandidateCount', Token);
        TempResult."Evaluated Candidate Count" := Token.AsValue().AsInteger();
        TempResult."Validation Status" := 'VALID';

        if TempResult.Action = RecommendReplacementLbl then begin
            Recommendation.Get('replacementItem', Token);
            ReplacementObject := Token.AsObject();
            ReplacementObject.Get('itemNo', Token);
            ActionCode := Token.AsValue().AsText();
            Item.Get(CopyStr(ActionCode, 1, MaxStrLen(Item."No.")));
            TempResult."Replacement Item No." := Item."No.";
            TempResult."Replacement Item Description" := Item.Description;
            TempResult."Replacement Inv. Base" := GetReplacementCurrentInventoryBase(SalesLine, Item);
            ReplacementObject.Get('proposedQuantity', Token);
            TempResult."Proposed Quantity" := Token.AsValue().AsDecimal();
            ReplacementObject.Get('proposedQuantityBase', Token);
            TempResult."Proposed Quantity Base" := Token.AsValue().AsDecimal();
            ReplacementObject.Get('similarityScore', Token);
            TempResult."Similarity Score" := Token.AsValue().AsDecimal();
            ReplacementObject.Get('reason', Token);
            TextValue := Token.AsValue().AsText();
            TempResult."Selection Reason" := CopyStr(TextValue, 1, MaxStrLen(TempResult."Selection Reason"));
        end;

        TempResult.Insert(true);
    end;

    local procedure GetCurrentInventoryBase(SalesLine: Record "Sales Line"): Decimal
    var
        Item: Record Item;
    begin
        Item.Get(SalesLine."No.");
        Item.SetRange("Location Filter", SalesLine."Location Code");
        Item.CalcFields(Inventory);
        exit(Item.Inventory);
    end;

    local procedure GetReplacementCurrentInventoryBase(SalesLine: Record "Sales Line"; Item: Record Item): Decimal
    begin
        Item.SetRange("Location Filter", SalesLine."Location Code");
        Item.CalcFields(Inventory);
        exit(Item.Inventory);
    end;

    local procedure HasTextValue(JsonObject: JsonObject; PropertyName: Text; ExpectedValue: Text): Boolean
    var
        ActualValue: Text;
    begin
        if not TryGetText(JsonObject, PropertyName, ActualValue) then
            exit(false);
        exit(ActualValue = ExpectedValue);
    end;

    local procedure TryGetText(JsonObject: JsonObject; PropertyName: Text; var Value: Text): Boolean
    var
        Token: JsonToken;
    begin
        if not JsonObject.Get(PropertyName, Token) or not Token.IsValue() then
            exit(false);
        if Token.AsValue().IsNull() or Token.AsValue().IsUndefined() then
            exit(false);
        Value := Token.AsValue().AsText();
        exit(true);
    end;

    local procedure TryGetInteger(JsonObject: JsonObject; PropertyName: Text; var Value: Integer): Boolean
    var
        Token: JsonToken;
    begin
        if not JsonObject.Get(PropertyName, Token) or not Token.IsValue() then
            exit(false);
        Value := Token.AsValue().AsInteger();
        exit(true);
    end;

    local procedure TryGetDecimal(JsonObject: JsonObject; PropertyName: Text; var Value: Decimal): Boolean
    var
        Token: JsonToken;
    begin
        if not JsonObject.Get(PropertyName, Token) or not Token.IsValue() then
            exit(false);
        Value := Token.AsValue().AsDecimal();
        exit(true);
    end;

    local procedure IsAllowedAction(ActionCode: Text): Boolean
    begin
        exit(
            (ActionCode = NoActionInventorySufficientLbl) or
            (ActionCode = RecommendReplacementLbl) or
            (ActionCode = NoReplacementFoundLbl) or
            (ActionCode = ErrorActionLbl));
    end;

    local procedure IsAllowedReasonCode(ReasonCode: Text): Boolean
    begin
        exit(
            (ReasonCode = InventorySufficientLbl) or
            (ReasonCode = MatchFoundLbl) or
            (ReasonCode = NoCandidatesLbl) or
            (ReasonCode = InsufficientCandidateInventoryLbl) or
            (ReasonCode = SimilarityBelowThresholdLbl) or
            (ReasonCode = CriticalAttributeConflictLbl) or
            (ReasonCode = InsufficientProductInformationLbl) or
            (ReasonCode = IncompleteCandidateRetrievalLbl) or
            (ReasonCode = ToolErrorLbl));
    end;

    local procedure SetError(var ErrorMessage: Text; MessageText: Text): Boolean
    begin
        ErrorMessage := MessageText;
        exit(false);
    end;
}
