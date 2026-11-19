codeunit 52004 "MCON Item Attribute Mgt."
{
    procedure GetAttributes(ItemNo: Code[20]): JsonArray
    var
        AttributeValueMapping: Record "Item Attribute Value Mapping";
        ItemAttribute: Record "Item Attribute";
        ItemAttributeTranslation: Record "Item Attribute Translation";
        ItemAttributeValue: Record "Item Attribute Value";
        LanguageMgt: Codeunit Language;
        Attributes: JsonArray;
        AttributeObject: JsonObject;
        AttributeName: Text[250];
        AttributeValueText: Text;
        LanguageCode: Code[10];
    begin
        AttributeValueMapping.SetRange("Table ID", Database::Item);
        AttributeValueMapping.SetRange("No.", ItemNo);
        LanguageCode := LanguageMgt.GetLanguageCode(GlobalLanguage());
        if AttributeValueMapping.FindSet() then
            repeat
                if ItemAttribute.Get(AttributeValueMapping."Item Attribute ID") then
                    if ItemAttributeValue.Get(
                        AttributeValueMapping."Item Attribute ID",
                        AttributeValueMapping."Item Attribute Value ID")
                    then begin
                        AttributeName := ItemAttribute.Name;
                        if ItemAttributeTranslation.Get(ItemAttribute."ID", LanguageCode) then
                            AttributeName := ItemAttributeTranslation.Name;
                        AttributeValueText := GetFormattedAttributeValue(ItemAttribute, ItemAttributeValue);
                        Clear(AttributeObject);
                        AttributeObject.Add('attributeName', AttributeName);
                        AttributeObject.Add('attributeValue', AttributeValueText);
                        AttributeObject.Add('unitOfMeasure', ItemAttribute."Unit of Measure");
                        Attributes.Add(AttributeObject);
                    end;
            until AttributeValueMapping.Next() = 0;

        exit(Attributes);
    end;

    local procedure GetFormattedAttributeValue(ItemAttribute: Record "Item Attribute"; ItemAttributeValue: Record "Item Attribute Value"): Text
    var
        AttributeType: Text;
    begin
        if ItemAttributeValue.Value <> '' then
            exit(ItemAttributeValue.Value);
        AttributeType := Format(ItemAttribute.Type);
        if AttributeType = 'Date' then
            exit(Format(ItemAttributeValue."Date Value"));
        if (AttributeType = 'Integer') or (AttributeType = 'Decimal') then
            exit(Format(ItemAttributeValue."Numeric Value"));
        if ItemAttributeValue."Date Value" <> 0D then
            exit(Format(ItemAttributeValue."Date Value"));
        if ItemAttributeValue."Numeric Value" <> 0 then
            exit(Format(ItemAttributeValue."Numeric Value"));
        exit('');
    end;
}
