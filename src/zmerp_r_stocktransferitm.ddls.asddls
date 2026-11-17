@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Stock Transfer Item Entity'
@ObjectModel.sapObjectNodeType.name: 'ZMERP_ST_ITM'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZMERP_R_STOCKTRANSFERITM
  as select from zmerp_st_itm
  association to parent ZMERP_R_STOCKTRANSFER as _StockTransfer on $projection.HeaderUUID = _StockTransfer.DocumentUUID
  association [0..1] to ZMERP_R_ITEM          as _Item          on $projection.ItemCode = _Item.ItemCode
  association [0..1] to I_UnitOfMeasure       as _UnitOfMeasure on $projection.UnitOfMeasure = _UnitOfMeasure.UnitOfMeasure
  association [0..1] to ZMERP_R_STOCK_BALANCE as _Stock         on  $projection.WarehouseCode = _Stock.WarehouseCode
                                                                and $projection.ItemCode      = _Stock.ItemCode
                                                                and $projection.UnitOfMeasure = _Stock.UnitOfMeasure
{
  key item_uuid                as ItemUUID,
      header_uuid              as HeaderUUID,

      item_no                  as ItemNo,

      @ObjectModel.foreignKey.association: '_Item'
      item_code                as ItemCode,

      @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
      quantity                 as Quantity,

      @ObjectModel.foreignKey.association: '_UnitOfMeasure'
      unit_of_measure          as UnitOfMeasure,

      warehouse_code           as WarehouseCode,
      receiving_warehouse_code as ReceivingWarehouseCode,

      @Semantics.user.createdBy: true
      created_by               as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at               as CreatedAt,
      @Semantics.user.localInstanceLastChangedBy: true
      local_last_changed_by    as LocalLastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at    as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at          as LastChangedAt,

      _StockTransfer,
      _Item,
      _UnitOfMeasure,
      _Stock
}
