codeunit 52006 "MCON Item Repl. Cand. Mgt."
{
    var
        InvalidPageErr: Label 'Page number must be positive and page size must be between 1 and 100.';
        SalesLineNotFoundErr: Label 'The sales order item line %1 does not exist or is not eligible.', Comment = '%1 = Sales line SystemId';
        ItemNotFoundErr: Label 'Item %1 does not exist.', Comment = '%1 = Item number';
        SearchDiagnosticsLbl: Label 'Other items in category "%1": %2; same sales unit "%3": %4; unblocked inventory items: %5; valid line unit "%6": %7; sufficient stock at location "%8": %9. Required original base quantity: %10.', Comment = '%1 = category, %2 = category count, %3 = sales unit, %4 = unit count, %5 = active inventory count, %6 = line unit, %7 = compatible unit count, %8 = location, %9 = eligible count, %10 = required base quantity';

    procedure GetCandidateCount(OriginalSalesLineSystemId: Guid): Integer
    var
        SalesLine: Record "Sales Line";
        OriginalItem: Record Item;
    begin
        GetEligibleSalesLine(OriginalSalesLineSystemId, SalesLine, OriginalItem);
        exit(CountCandidates(SalesLine, OriginalItem));
    end;

    procedure GetCandidates(OriginalSalesLineSystemId: Guid; PageNumber: Integer; PageSize: Integer): JsonObject
    var
        SalesLine: Record "Sales Line";
        OriginalItem: Record Item;
        CandidateItem: Record Item;
        CandidateArray: JsonArray;
        CandidateObject: JsonObject;
        CandidateCount: Integer;
        EligibleIndex: Integer;
        FirstIndex: Integer;
        LastIndex: Integer;
        CandidateSetId: Text;
        ResultObject: JsonObject;
    begin
        ValidatePage(PageNumber, PageSize);
        GetEligibleSalesLine(OriginalSalesLineSystemId, SalesLine, OriginalItem);

        CandidateCount := CountCandidates(SalesLine, OriginalItem);
        FirstIndex := ((PageNumber - 1) * PageSize) + 1;
        LastIndex := PageNumber * PageSize;
        CandidateSetId := Format(OriginalSalesLineSystemId);

        if FirstIndex <= CandidateCount then begin
            SetCandidateFilters(CandidateItem, OriginalItem);
            CandidateItem.SetCurrentKey("No.");
            if CandidateItem.FindSet(false) then
                repeat
                    if IsEligibleCandidateItem(SalesLine, OriginalItem, CandidateItem) then begin
                        EligibleIndex += 1;
                        if (EligibleIndex >= FirstIndex) and (EligibleIndex <= LastIndex) then begin
                            CandidateObject := BuildCandidateObject(
                                CandidateItem, SalesLine."Location Code", SalesLine."Outstanding Qty. (Base)");
                            CandidateArray.Add(CandidateObject);
                        end;
                    end;
                until (CandidateItem.Next() = 0) or (EligibleIndex >= LastIndex);
        end;

        ResultObject.Add('candidateSetId', CandidateSetId);
        ResultObject.Add('originalSalesLineSystemId', CandidateSetId);
        ResultObject.Add('pageNumber', PageNumber);
        ResultObject.Add('pageSize', PageSize);
        ResultObject.Add('totalCandidateCount', CandidateCount);
        ResultObject.Add('hasMoreCandidates', LastIndex < CandidateCount);
        ResultObject.Add('candidates', CandidateArray);
        exit(ResultObject);
    end;

    procedure IsEligibleCandidate(SalesLine: Record "Sales Line"; CandidateItemNo: Code[20]): Boolean
    var
        OriginalItem: Record Item;
        CandidateItem: Record Item;
    begin
        if SalesLine.Type <> SalesLine.Type::Item then
            exit(false);
        if SalesLine."Document Type" <> SalesLine."Document Type"::Order then
            exit(false);
        if SalesLine."No." = '' then
            exit(false);
        if not OriginalItem.Get(SalesLine."No.") then
            exit(false);
        if not CandidateItem.Get(CandidateItemNo) then
            exit(false);
        if not IsReplacementRequired(SalesLine, OriginalItem) then
            exit(false);

        exit(IsEligibleCandidateItem(SalesLine, OriginalItem, CandidateItem));
    end;

    procedure CollectCandidates(SalesLine: Record "Sales Line"; var TempCandidates: Record "MCON Item Repl. Result" temporary): JsonArray
    var
        OriginalItem: Record Item;
        CandidateItem: Record Item;
        ContextMgt: Codeunit "MCON Item Repl. Context Mgt.";
        Candidates: JsonArray;
        EntryNo: Integer;
    begin
        TempCandidates.Reset();
        TempCandidates.DeleteAll();
        OriginalItem.Get(SalesLine."No.");
        SetCandidateFilters(CandidateItem, OriginalItem);
        CandidateItem.SetCurrentKey("No.");
        if CandidateItem.FindSet() then
            repeat
                if IsEligibleCandidateItem(SalesLine, OriginalItem, CandidateItem) then begin
                    EntryNo += 1;
                    TempCandidates.Init();
                    TempCandidates."Entry No." := EntryNo;
                    TempCandidates."Sales Order No." := SalesLine."Document No.";
                    TempCandidates."Original Sales Line SystemId" := SalesLine.SystemId;
                    TempCandidates."Original Line No." := SalesLine."Line No.";
                    TempCandidates."Original Item No." := OriginalItem."No.";
                    TempCandidates."Original Item Description" := OriginalItem.Description;
                    TempCandidates."Source Modified At" := SalesLine.SystemModifiedAt;
                    TempCandidates."Location Code" := SalesLine."Location Code";
                    TempCandidates."Unit of Measure Code" := SalesLine."Unit of Measure Code";
                    TempCandidates."Required Quantity" := SalesLine."Outstanding Quantity";
                    TempCandidates."Required Quantity Base" := SalesLine."Outstanding Qty. (Base)";
                    TempCandidates."Current Inventory Base" := ContextMgt.GetCurrentInventoryBase(OriginalItem."No.", SalesLine."Location Code");
                    TempCandidates."Replacement Required" := true;
                    TempCandidates."Replacement Item No." := CandidateItem."No.";
                    TempCandidates."Replacement Item Description" := CandidateItem.Description;
                    TempCandidates."Replacement Inv. Base" := GetCurrentInventoryBase(CandidateItem, SalesLine."Location Code");
                    TempCandidates.Insert();
                    Candidates.Add(BuildCandidateObject(CandidateItem, SalesLine."Location Code", SalesLine."Outstanding Qty. (Base)"));
                end;
            until CandidateItem.Next() = 0;
        exit(Candidates);
    end;

    procedure GetSearchDiagnostics(SalesLine: Record "Sales Line"): Text
    var
        OriginalItem: Record Item;
        CandidateItem: Record Item;
        CandidateUOM: Record "Item Unit of Measure";
        CategoryCount: Integer;
        SalesUnitCount: Integer;
        ActiveItemCount: Integer;
        LineUnitCount: Integer;
        EligibleCount: Integer;
    begin
        OriginalItem.Get(SalesLine."No.");
        CandidateItem.SetFilter("No.", '<>%1', OriginalItem."No.");
        CandidateItem.SetRange("Item Category Code", OriginalItem."Item Category Code");
        CategoryCount := CandidateItem.Count();
        CandidateItem.SetRange("Sales Unit of Measure", OriginalItem."Sales Unit of Measure");
        SalesUnitCount := CandidateItem.Count();
        CandidateItem.SetRange(Blocked, false);
        CandidateItem.SetRange("Sales Blocked", false);
        CandidateItem.SetRange(Type, CandidateItem.Type::Inventory);
        ActiveItemCount := CandidateItem.Count();
        if CandidateItem.FindSet() then
            repeat
                if CandidateUOM.Get(CandidateItem."No.", SalesLine."Unit of Measure Code") then
                    if CandidateUOM."Qty. per Unit of Measure" > 0 then
                        LineUnitCount += 1;
                if IsEligibleCandidateItem(SalesLine, OriginalItem, CandidateItem) then
                    EligibleCount += 1;
            until CandidateItem.Next() = 0;
        exit(StrSubstNo(SearchDiagnosticsLbl,
            OriginalItem."Item Category Code", CategoryCount, OriginalItem."Sales Unit of Measure", SalesUnitCount,
            ActiveItemCount, SalesLine."Unit of Measure Code", LineUnitCount, SalesLine."Location Code",
            EligibleCount, SalesLine."Outstanding Qty. (Base)"));
    end;

    local procedure CountCandidates(SalesLine: Record "Sales Line"; OriginalItem: Record Item): Integer
    var
        CandidateItem: Record Item;
        CandidateCount: Integer;
    begin
        if not IsReplacementRequired(SalesLine, OriginalItem) then
            exit(0);

        SetCandidateFilters(CandidateItem, OriginalItem);
        CandidateItem.SetCurrentKey("No.");
        if CandidateItem.FindSet(false) then
            repeat
                if IsEligibleCandidateItem(SalesLine, OriginalItem, CandidateItem) then
                    CandidateCount += 1;
            until CandidateItem.Next() = 0;

        exit(CandidateCount);
    end;

    local procedure SetCandidateFilters(var CandidateItem: Record Item; OriginalItem: Record Item)
    begin
        //SetCurrenKey For Performance Optimization
        CandidateItem.SetRange("Item Category Code", OriginalItem."Item Category Code");
        CandidateItem.SetRange("Sales Unit of Measure", OriginalItem."Sales Unit of Measure");
        CandidateItem.SetRange(Blocked, false);
        CandidateItem.SetRange("Sales Blocked", false);
        CandidateItem.SetRange(Type, CandidateItem.Type::Inventory);
        CandidateItem.SetFilter("No.", '<>%1', OriginalItem."No.");
    end;

    local procedure GetEligibleSalesLine(OriginalSalesLineSystemId: Guid; var SalesLine: Record "Sales Line"; var OriginalItem: Record Item)
    begin
        SalesLine.SetRange(SystemId, OriginalSalesLineSystemId);
        SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.SetFilter("No.", '<>%1', '');
        SalesLine.SetFilter("Outstanding Quantity", '>%1', 0);
        if not SalesLine.FindFirst() then
            Error(SalesLineNotFoundErr, Format(OriginalSalesLineSystemId));
        if not OriginalItem.Get(SalesLine."No.") then
            Error(ItemNotFoundErr, SalesLine."No.");
    end;

    local procedure IsEligibleCandidateItem(SalesLine: Record "Sales Line"; OriginalItem: Record Item; CandidateItem: Record Item): Boolean
    var
        CandidateUOM: Record "Item Unit of Measure";
        CandidateInventoryBase: Decimal;
    begin
        if (SalesLine."Outstanding Quantity" <= 0) or (SalesLine."Outstanding Qty. (Base)" <= 0) then
            exit(false);
        if CandidateItem."No." = OriginalItem."No." then
            exit(false);
        if CandidateItem."Item Category Code" <> OriginalItem."Item Category Code" then
            exit(false);
        if CandidateItem."Sales Unit of Measure" <> OriginalItem."Sales Unit of Measure" then
            exit(false);
        if CandidateItem.Blocked or CandidateItem."Sales Blocked" then
            exit(false);
        if CandidateItem.Type <> CandidateItem.Type::Inventory then
            exit(false);
        if not CandidateUOM.Get(CandidateItem."No.", SalesLine."Unit of Measure Code") then
            exit(false);
        if CandidateUOM."Qty. per Unit of Measure" <= 0 then
            exit(false);

        CandidateInventoryBase := GetCurrentInventoryBase(CandidateItem, SalesLine."Location Code");
        exit(
            (CandidateInventoryBase > 0) and
            (CandidateInventoryBase >= SalesLine."Outstanding Qty. (Base)") and
            (CandidateInventoryBase >= SalesLine."Outstanding Quantity" * CandidateUOM."Qty. per Unit of Measure"));
    end;

    local procedure IsReplacementRequired(SalesLine: Record "Sales Line"; OriginalItem: Record Item): Boolean
    begin
        exit(
            GetCurrentInventoryBase(OriginalItem, SalesLine."Location Code") <
            SalesLine."Outstanding Qty. (Base)");
    end;

    local procedure BuildCandidateObject(CandidateItem: Record Item; LocationCode: Code[10]; RequiredQuantityBase: Decimal): JsonObject
    var
        AttributeMgt: Codeunit "MCON Item Attribute Mgt.";
        CurrentInventoryBase: Decimal;
        CandidateObject: JsonObject;
    begin
        CurrentInventoryBase := GetCurrentInventoryBase(CandidateItem, LocationCode);
        CandidateObject.Add('itemNo', CandidateItem."No.");
        CandidateObject.Add('description', CandidateItem.Description);
        CandidateObject.Add('description2', CandidateItem."Description 2");
        CandidateObject.Add('searchDescription', CandidateItem."Search Description");
        CandidateObject.Add('itemCategoryCode', CandidateItem."Item Category Code");
        CandidateObject.Add('salesUnitOfMeasureCode', CandidateItem."Sales Unit of Measure");
        CandidateObject.Add('baseUnitOfMeasureCode', CandidateItem."Base Unit of Measure");
        CandidateObject.Add('currentInventoryBase', CurrentInventoryBase);
        CandidateObject.Add('requiredQuantityBase', RequiredQuantityBase);
        CandidateObject.Add('sufficientCurrentInventory', CurrentInventoryBase >= RequiredQuantityBase);
        CandidateObject.Add('attributes', AttributeMgt.GetAttributes(CandidateItem."No."));
        exit(CandidateObject);
    end;

    local procedure GetCurrentInventoryBase(var Item: Record Item; LocationCode: Code[10]): Decimal
    begin
        Item.SetRange("Location Filter", LocationCode);
        Item.CalcFields(Inventory);
        exit(Item.Inventory);
    end;

    local procedure ValidatePage(PageNumber: Integer; PageSize: Integer)
    begin
        if (PageNumber < 1) or (PageSize < 1) or (PageSize > 100) then
            Error(InvalidPageErr);
        if PageNumber > (2147483647 div PageSize) then
            Error(InvalidPageErr);
    end;
}
