@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Goods Issue Warehouse Stock'
@Metadata.ignorePropagatedAnnotations: true

// Current stock in the warehouse of a goods issue (saved header), per item and unit.
// Read by the goods issue lines (column "In Stock"); a document that was never saved shows no stock.
define view entity ZMERP_I_GI_STOCK
  as select from ZMERP_R_GOODSISSUE    as gih
    inner join   ZMERP_R_STOCK_BALANCE as bal on  bal.CompanyCode   = gih.CompanyCode
                                              and bal.WarehouseCode = gih.WarehouseCode
{
  key gih.DocumentUUID  as DocumentUUID,
  key bal.ItemCode      as ItemCode,
  key bal.UnitOfMeasure as UnitOfMeasure,

      @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
      bal.Quantity      as StockQuantity
}
