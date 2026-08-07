@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Warehouse Value Help'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true

define view entity ZMERP_I_WAREHOUSE_VH
  as select from ZMERP_R_WAREHOUSE
{
  @Search.defaultSearchElement: true
  @Search.ranking: #HIGH
  key WarehouseCode,

  @Search.defaultSearchElement: true
  @Search.ranking: #HIGH
  @Search.fuzzinessThreshold: 0.7
  WarehouseName,

  @ObjectModel.text.element: [ 'CompanyName' ]
  @UI.textArrangement: #TEXT_FIRST
  CompanyCode,     
  _CompanyCode.CompanyName as CompanyName
}

where
  IsBlocked = ''
