@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Goods Receipt Item Projection View'
@Metadata.allowExtensions: true
@Search.searchable: true

define view entity ZMERP_C_GOODSRECEIPTITM
  as projection on ZMERP_R_GOODSRECEIPTITM
{
  key ItemUUID,
      HeaderUUID,

      /* zmerp_s_doc_itm_common */
      ItemNo,

      @Search.defaultSearchElement: true
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMERP_I_ITEM_VH', element: 'ItemCode' }, useForValidation: true }]
      ItemCode,

      Quantity,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_UnitOfMeasureStdVH', element: 'UnitOfMeasure' }, useForValidation: true }]
      UnitOfMeasure,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_CurrencyStdVH', element: 'CurrencyCode' }, useForValidation: true }]
      CurrencyCode,

      Price,
      NetAmount,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMERP_I_VAT_RATE_VH', element: 'VatCode' }, useForValidation: true }]
      VatCode,

      VatAmount,
      GrossAmount,

      /* zmerp_gr_itm */
      PoItemReferenceUUID,

      @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
      _PoProgress.OpenQuantity as PoOpenQuantity,

      // Empty for lines added manually (without purchase order item reference)
      _PoProgress.PoDocumentNumber as PoDocumentNumber,

      /* zmerp_s_admin */
      CreatedBy,
      CreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      /* Redirected associations */
      _GoodsReceipt       : redirected to parent ZMERP_C_GOODSRECEIPT,
      _Item               : redirected to ZMERP_C_ITEM,
      _VatRate            : redirected to ZMERP_C_VAT_RATE,
      _PurchaseOrderItem,
      _UnitOfMeasure,
      _Currency
}
