@EndUserText.label: 'Stock Movement Projection View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZMERP_C_STOCK_MOVEMENT
  provider contract transactional_query
  as projection on ZMERP_R_STOCK_MOVEMENT
{
  key MovementUUID,

      @ObjectModel.text.element: [ 'CompanyName' ]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMERP_I_COMPANY_CODE_VH', element: 'CompanyCode' } }]
      CompanyCode,

      @ObjectModel.text.element: [ 'WarehouseName' ]
      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZMERP_I_WAREHOUSE_VH', element: 'WarehouseCode' },
        additionalBinding: [{ localElement: 'CompanyCode', element: 'CompanyCode', usage: #FILTER }]
      }]
      WarehouseCode,

      @ObjectModel.text.element: [ 'ItemDescription' ]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMERP_I_ITEM_VH', element: 'ItemCode' } }]
      @Search.defaultSearchElement: true
      @Search.ranking: #HIGH
      ItemCode,

      _CompanyCode.CompanyName as CompanyName,
      _Warehouse.WarehouseName as WarehouseName,

      @Search.defaultSearchElement: true
      @Search.ranking: #HIGH
      @Search.fuzzinessThreshold: 0.7
      _Item.Description        as ItemDescription,

      PostingDate,
      Direction,

      DocumentType,
      DocumentUUID,

      @Search.defaultSearchElement: true
      DocumentNumber,

      Quantity,
      UnitOfMeasure,

      StockValue,
      CurrencyCode
}
