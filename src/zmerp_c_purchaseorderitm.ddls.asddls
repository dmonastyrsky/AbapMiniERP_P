@EndUserText.label: 'Purchase Order Item Projection View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Search.searchable: true

define view entity ZMERP_C_PURCHASEORDERITM
  as projection on ZMERP_R_PURCHASEORDERITM
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

      /* zmerp_po_itm */
      DeliveryCompleted,

      /* zmerp_s_admin */
      CreatedBy,
      CreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      /* Redirected associations */
      _PurchaseOrder : redirected to parent ZMERP_C_PURCHASEORDER,
      _Item          : redirected to ZMERP_C_ITEM,
      _VatRate       : redirected to ZMERP_C_VAT_RATE,
      _UnitOfMeasure,
      _Currency
}
