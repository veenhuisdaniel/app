codeunit 52005 "MCON Item Repl. Context Mgt."
{
    var
        InventoryCalculationLbl: Label 'CURRENT_INVENTORY', Locked = true;
        OrderNotFoundErr: Label 'Sales order %1 does not exist.', Comment = '%1 = Sales order number';
        ItemNotFoundErr: Label 'Item %1 does not exist.', Comment = '%1 = Item number';

    procedure GetSalesOrderContext(SalesOrderNo: Code[20]): JsonObject
    var
        SalesHeader: Record "Sales Header";
        ContextObject: JsonObject;
    begin
        if not SalesHeader.Get(SalesHeader."Document Type"::Order, SalesOrderNo) then
            Error(OrderNotFoundErr, SalesOrderNo);

        ContextObject.Add('salesOrderNo', SalesHeader."No.");
        ContextObject.Add('inventoryCalculation', InventoryCalculationLbl);
        ContextObject.Add('salesLines', GetEligibleSalesLines(SalesOrderNo));
        exit(ContextObject);
    end;

    procedure GetEligibleSalesLines(SalesOrderNo: Code[20]): JsonArray
    var
        SalesLine: Record "Sales Line";
        SalesLines: JsonArray;
    begin
        SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
        SalesLine.SetRange("Document No.", SalesOrderNo);
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.SetFilter("No.", '<>%1', '');
        SalesLine.SetFilter("Outstanding Quantity", '>%1', 0);

        if SalesLine.FindSet(false) then
            repeat
                SalesLines.Add(GetSalesLineContext(SalesLine));
            until SalesLine.Next() = 0;

        exit(SalesLines);
    end;

    procedure GetCurrentInventoryBase(ItemNo: Code[20]; LocationCode: Code[10]): Decimal
    var
        Item: Record Item;
    begin
        if not Item.Get(ItemNo) then
            Error(ItemNotFoundErr, ItemNo);

        // A blank location intentionally filters to entries with a blank Location Code.
        Item.SetRange("Location Filter", LocationCode);
        Item.CalcFields(Inventory);
        exit(Item.Inventory);
    end;

    procedure IsReplacementRequired(CurrentInventoryBase: Decimal; OutstandingQuantityBase: Decimal): Boolean
    begin
        exit(CurrentInventoryBase < OutstandingQuantityBase);
    end;

    procedure GetSalesLineContext(SalesLine: Record "Sales Line"): JsonObject
    var
        Item: Record Item;
        AttributeMgt: Codeunit "MCON Item Attribute Mgt.";
        CurrentInventoryBase: Decimal;
        SalesLineObject: JsonObject;
    begin
        if not Item.Get(SalesLine."No.") then
            Error(ItemNotFoundErr, SalesLine."No.");

        CurrentInventoryBase := GetCurrentInventoryBase(Item."No.", SalesLine."Location Code");
        SalesLineObject.Add('originalSalesLineSystemId', Format(SalesLine.SystemId));
        SalesLineObject.Add('originalLineNo', SalesLine."Line No.");
        SalesLineObject.Add('originalItemNo', Item."No.");
        SalesLineObject.Add('originalItemDescription', Item.Description);
        SalesLineObject.Add('originalItemDescription2', Item."Description 2");
        SalesLineObject.Add('searchDescription', Item."Search Description");
        SalesLineObject.Add('itemCategoryCode', Item."Item Category Code");
        SalesLineObject.Add('salesUnitOfMeasureCode', Item."Sales Unit of Measure");
        SalesLineObject.Add('lineUnitOfMeasureCode', SalesLine."Unit of Measure Code");
        SalesLineObject.Add('baseUnitOfMeasureCode', Item."Base Unit of Measure");
        SalesLineObject.Add('locationCode', SalesLine."Location Code");
        SalesLineObject.Add('outstandingQuantity', SalesLine."Outstanding Quantity");
        SalesLineObject.Add('outstandingQuantityBase', SalesLine."Outstanding Qty. (Base)");
        SalesLineObject.Add('currentInventoryBase', CurrentInventoryBase);
        SalesLineObject.Add(
            'replacementRequired',
            IsReplacementRequired(CurrentInventoryBase, SalesLine."Outstanding Qty. (Base)"));
        SalesLineObject.Add('attributes', AttributeMgt.GetAttributes(Item."No."));
        exit(SalesLineObject);
    end;
}
