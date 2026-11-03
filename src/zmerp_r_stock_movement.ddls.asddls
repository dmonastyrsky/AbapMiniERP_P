@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Stock Movement Root Entity'
@Metadata.ignorePropagatedAnnotations: true

// Stock journal ZMERP_STOCK_MOV, read-only (no BDEF): rows are written by the document savers.
// Receipts have a positive quantity; issues (goods issue, later) will have a negative one.
define root view entity ZMERP_R_STOCK_MOVEMENT
  as select from zmerp_stock_mov

  association [0..1] to ZMERP_R_COMPANY_CODE as _CompanyCode  on $projection.CompanyCode   = _CompanyCode.CompanyCode
  association [0..1] to ZMERP_R_WAREHOUSE    as _Warehouse    on $projection.WarehouseCode = _Warehouse.WarehouseCode
  association [0..1] to ZMERP_R_ITEM         as _Item         on $projection.ItemCode      = _Item.ItemCode
  association [0..1] to ZMERP_R_GOODSRECEIPT as _GoodsReceipt on $projection.DocumentUUID  = _GoodsReceipt.DocumentUUID
{
  key movement_uuid   as MovementUUID,

      company_code    as CompanyCode,
      warehouse_code  as WarehouseCode,
      item_code       as ItemCode,

      posting_date    as PostingDate,

      @EndUserText.label: 'Direction'
      cast( case when cast( quantity as abap.dec( 13, 3 ) ) >= 0
                 then 'Receipt'
                 else 'Issue'
            end as abap.char( 10 ) ) as Direction,

      document_type   as DocumentType,
      document_uuid   as DocumentUUID,

      // Goods issues will add the number of their document here
      @EndUserText.label: 'Document'
      _GoodsReceipt.DocumentNumber as DocumentNumber,

      @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
      quantity        as Quantity,
      unit_of_measure as UnitOfMeasure,

      @EndUserText.label: 'Value'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      amount          as StockValue,
      currency_code   as CurrencyCode,

      _CompanyCode,
      _Warehouse,
      _Item
}
