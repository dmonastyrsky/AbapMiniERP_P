@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Goods Issue Item Projection View'
@Metadata.allowExtensions: true
@Search.searchable: true

define view entity ZMERP_C_GOODSISSUEITM
  as projection on ZMERP_R_GOODSISSUEITM
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

      /* zmerp_gi_itm */
      SoItemReferenceUUID,

      @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
      _SoProgress.OpenQuantity as SoOpenQuantity,

      // Empty for lines added manually (without sales order item reference)
      _SoProgress.SoDocumentNumber as SoDocumentNumber,

      // Current stock of the item in the warehouse of the document (ST1)
      @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
      _Stock.StockQuantity as StockQuantity,

      /* zmerp_s_admin */
      CreatedBy,
      CreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      /* Redirected associations */
      _GoodsIssue     : redirected to parent ZMERP_C_GOODSISSUE,
      _Item           : redirected to ZMERP_C_ITEM,
      _VatRate        : redirected to ZMERP_C_VAT_RATE,
      _SalesOrderItem,
      _UnitOfMeasure,
      _Currency
}
