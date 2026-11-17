@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Stock Transfer Item Projection View'
@Metadata.allowExtensions: true
@Search.searchable: true

define view entity ZMERP_C_STOCKTRANSFERITM
  as projection on ZMERP_R_STOCKTRANSFERITM
{
  key ItemUUID,
      HeaderUUID,

      ItemNo,

      @Search.defaultSearchElement: true
      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZMERP_I_ITEM_VH', element: 'ItemCode' },
        additionalBinding: [{ element: 'ItemTypeCode', localConstant: 'P', usage: #FILTER }],
        useForValidation: true
      }]
      ItemCode,

      Quantity,
      
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_UnitOfMeasureStdVH', element: 'UnitOfMeasure' }, useForValidation: true }]
      UnitOfMeasure,

      @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
      _Stock.Quantity as StockQuantity,

      CreatedBy,
      CreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      _StockTransfer : redirected to parent ZMERP_C_STOCKTRANSFER,
      _Item          : redirected to ZMERP_C_ITEM,
      _UnitOfMeasure
}
