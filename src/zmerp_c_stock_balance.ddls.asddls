@EndUserText.label: 'Stock Balance Projection View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZMERP_C_STOCK_BALANCE
  provider contract transactional_query
  as projection on ZMERP_R_STOCK_BALANCE
{
      @ObjectModel.text.element: [ 'CompanyName' ]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMERP_I_COMPANY_CODE_VH', element: 'CompanyCode' } }]
  key CompanyCode,

      @ObjectModel.text.element: [ 'WarehouseName' ]
      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZMERP_I_WAREHOUSE_VH', element: 'WarehouseCode' },
        additionalBinding: [{ localElement: 'CompanyCode', element: 'CompanyCode', usage: #FILTER }]
      }]
  key WarehouseCode,

      @ObjectModel.text.element: [ 'ItemDescription' ]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMERP_I_ITEM_VH', element: 'ItemCode' } }]
      @Search.defaultSearchElement: true
      @Search.ranking: #HIGH
  key ItemCode,

  key UnitOfMeasure,
  key CurrencyCode,

      _CompanyCode.CompanyName     as CompanyName,
      _Warehouse.WarehouseName     as WarehouseName,

      @Search.defaultSearchElement: true
      @Search.ranking: #HIGH
      @Search.fuzzinessThreshold: 0.7
      _Item.Description            as ItemDescription,

      @ObjectModel.text.element: [ 'ItemGroupDescription' ]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMERP_I_ITEM_GROUP_VH', element: 'ItemGroupCode' } }]
      _Item.ItemGroupCode          as ItemGroupCode,
      _Item._ItemGroup.Description as ItemGroupDescription,

      Quantity,
      StockValue,

      /* Associations */
      _Movements : redirected to ZMERP_C_STOCK_MOVEMENT
}
