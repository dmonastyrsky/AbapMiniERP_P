@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Purchase Order Item Entity'
@ObjectModel.sapObjectNodeType.name: 'ZMERP_PO_ITM'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZMERP_R_PURCHASEORDERITM
  as select from zmerp_po_itm
  association to parent ZMERP_R_PURCHASEORDER as _PurchaseOrder on $projection.HeaderUUID = _PurchaseOrder.DocumentUUID
  association [0..1] to ZMERP_R_ITEM          as _Item          on $projection.ItemCode = _Item.ItemCode
  association [0..1] to ZMERP_R_VAT_RATE      as _VatRate       on $projection.VatCode = _VatRate.VatCode
  association [0..1] to I_UnitOfMeasure       as _UnitOfMeasure on $projection.UnitOfMeasure = _UnitOfMeasure.UnitOfMeasure
  association [0..1] to I_Currency            as _Currency      on $projection.CurrencyCode = _Currency.Currency
{
  key item_uuid             as ItemUUID,
      header_uuid           as HeaderUUID,

      /* zmerp_s_doc_itm_common */
      item_no               as ItemNo,

      @ObjectModel.foreignKey.association: '_Item'
      item_code             as ItemCode,

      @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
      quantity              as Quantity,

      @ObjectModel.foreignKey.association: '_UnitOfMeasure'
      unit_of_measure       as UnitOfMeasure,

      @ObjectModel.foreignKey.association: '_Currency'
      currency_code         as CurrencyCode,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      price                 as Price,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      net_amount            as NetAmount,

      @ObjectModel.foreignKey.association: '_VatRate'
      vat_code              as VatCode,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      vat_amount            as VatAmount,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      gross_amount          as GrossAmount,

      /* zmerp_po_itm */
      delivery_completed    as DeliveryCompleted,

      /* zmerp_s_admin */
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.localInstanceLastChangedBy: true
      local_last_changed_by as LocalLastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,
      
      /* Associations */
      _PurchaseOrder,
      _Item,
      _VatRate,
      _UnitOfMeasure,
      _Currency
}
