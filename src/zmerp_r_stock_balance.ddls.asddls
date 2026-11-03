@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Stock Balance Root Entity'
@Metadata.ignorePropagatedAnnotations: true

// Current stock per company, warehouse, item and unit: sum of all movements of ZMERP_STOCK_MOV.
// Read-only (no BDEF); services have no movements. Also read by ZCL_MERP_STOCK_SEL.
define root view entity ZMERP_R_STOCK_BALANCE
  as select from zmerp_stock_mov

  association [0..1] to ZMERP_R_COMPANY_CODE   as _CompanyCode on  $projection.CompanyCode   = _CompanyCode.CompanyCode
  association [0..1] to ZMERP_R_WAREHOUSE      as _Warehouse   on  $projection.WarehouseCode = _Warehouse.WarehouseCode
  association [0..1] to ZMERP_R_ITEM           as _Item        on  $projection.ItemCode      = _Item.ItemCode
  association [0..*] to ZMERP_R_STOCK_MOVEMENT as _Movements   on  $projection.CompanyCode   = _Movements.CompanyCode
                                                                and $projection.WarehouseCode = _Movements.WarehouseCode
                                                                and $projection.ItemCode      = _Movements.ItemCode
                                                                and $projection.UnitOfMeasure = _Movements.UnitOfMeasure
                                                                and $projection.CurrencyCode  = _Movements.CurrencyCode
{
  key company_code    as CompanyCode,
  key warehouse_code  as WarehouseCode,
  key item_code       as ItemCode,
  key unit_of_measure as UnitOfMeasure,
  key currency_code   as CurrencyCode,

      @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
      sum( quantity ) as Quantity,

      @EndUserText.label: 'Stock Value'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      sum( amount )   as StockValue,

      _CompanyCode,
      _Warehouse,
      _Item,
      _Movements
}
group by company_code,
         warehouse_code,
         item_code,
         unit_of_measure,
         currency_code
