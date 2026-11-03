@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Purchase Order Item Progress'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZMERP_I_PO_PROGRESS
  as select from ZMERP_R_PURCHASEORDERITM  as poi
    left outer join ZMERP_I_PO_ITEM_GR_TOTALS  as rec on rec.PoItemUUID = poi.ItemUUID

  association [1..1] to ZMERP_R_PURCHASEORDER as _PurchaseOrder on $projection.PoHeaderUUID = _PurchaseOrder.DocumentUUID
  association [0..1] to ZMERP_R_ITEM          as _Item          on $projection.ItemCode = _Item.ItemCode
{
  key poi.ItemUUID                        as PoItemUUID,
      poi.HeaderUUID                      as PoHeaderUUID,
      poi.ItemNo                          as PoItemNo,
      poi.ItemCode                        as ItemCode,
      poi.UnitOfMeasure                   as UnitOfMeasure,
      poi.CurrencyCode                    as CurrencyCode,
      poi.VatCode                         as VatCode,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      poi.Price                           as Price,

      _PurchaseOrder.DocumentNumber       as PoDocumentNumber,
      _PurchaseOrder.Status               as PoStatus,      

      /* ---------- Ordered ---------- */
      @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
      poi.Quantity                        as OrderedQuantity,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      poi.NetAmount                       as OrderedNetAmount,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      poi.VatAmount                       as OrderedVatAmount,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      poi.GrossAmount                     as OrderedGrossAmount,

      /* ---------- Received (posted goods receipts) ---------- */
      @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
      cast( coalesce( cast( rec.ReceivedQuantity as abap.dec( 23, 3 ) ),
                      cast( 0 as abap.dec( 23, 3 ) ) ) as zmerp_quantity )
                                          as ReceivedQuantity,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      cast( coalesce( cast( rec.ReceivedNetAmount as abap.dec( 25, 2 ) ),
                      cast( 0 as abap.dec( 25, 2 ) ) ) as zmerp_net_amount )
                                          as ReceivedNetAmount,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      cast( coalesce( cast( rec.ReceivedVatAmount as abap.dec( 25, 2 ) ),
                      cast( 0 as abap.dec( 25, 2 ) ) ) as zmerp_vat_amount )
                                          as ReceivedVatAmount,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      cast( coalesce( cast( rec.ReceivedGrossAmount as abap.dec( 25, 2 ) ),
                      cast( 0 as abap.dec( 25, 2 ) ) ) as zmerp_gross_amount )
                                          as ReceivedGrossAmount,

      /* ---------- Open (ordered - received; negative = over-received) ---------- */
      @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
      cast( cast( poi.Quantity as abap.dec( 23, 3 ) )
            - coalesce( cast( rec.ReceivedQuantity as abap.dec( 23, 3 ) ),
                        cast( 0 as abap.dec( 23, 3 ) ) ) as zmerp_quantity )
                                          as OpenQuantity,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      cast( cast( poi.NetAmount as abap.dec( 25, 2 ) )
            - coalesce( cast( rec.ReceivedNetAmount as abap.dec( 25, 2 ) ),
                        cast( 0 as abap.dec( 25, 2 ) ) ) as zmerp_net_amount )
                                          as OpenNetAmount,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      cast( cast( poi.VatAmount as abap.dec( 25, 2 ) )
            - coalesce( cast( rec.ReceivedVatAmount as abap.dec( 25, 2 ) ),
                        cast( 0 as abap.dec( 25, 2 ) ) ) as zmerp_vat_amount )
                                          as OpenVatAmount,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      cast( cast( poi.GrossAmount as abap.dec( 25, 2 ) )
            - coalesce( cast( rec.ReceivedGrossAmount as abap.dec( 25, 2 ) ),
                        cast( 0 as abap.dec( 25, 2 ) ) ) as zmerp_gross_amount )
                                          as OpenGrossAmount,

      /* ---------- Receipt status: N = not received, P = partial, C = complete, O = over-received ---------- */
      cast( case
              when rec.PoItemUUID is null              then 'N'
              when rec.ReceivedQuantity < cast( poi.Quantity as abap.dec( 23, 3 ) ) then 'P'
              when rec.ReceivedQuantity = cast( poi.Quantity as abap.dec( 23, 3 ) ) then 'C'
              else 'O'
            end as abap.char( 1 ) )       as ReceiptStatus,

      /* Associations */
      _PurchaseOrder,
      _Item
}
