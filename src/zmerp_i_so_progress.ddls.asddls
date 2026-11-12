@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order Item Progress'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZMERP_I_SO_PROGRESS
  as select from ZMERP_R_SALESORDERITM  as soi
    left outer join ZMERP_I_SO_ITEM_GI_TOTALS as iss on iss.SoItemUUID = soi.ItemUUID

  association [1..1] to ZMERP_R_SALESORDER as _SalesOrder on $projection.SoHeaderUUID = _SalesOrder.DocumentUUID
  association [0..1] to ZMERP_R_ITEM       as _Item       on $projection.ItemCode = _Item.ItemCode
{
  key soi.ItemUUID                        as SoItemUUID,
      soi.HeaderUUID                      as SoHeaderUUID,
      soi.ItemNo                          as SoItemNo,
      soi.ItemCode                        as ItemCode,
      soi.UnitOfMeasure                   as UnitOfMeasure,
      soi.CurrencyCode                    as CurrencyCode,
      soi.VatCode                         as VatCode,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      soi.Price                           as Price,

      _SalesOrder.DocumentNumber          as SoDocumentNumber,
      _SalesOrder.Status                  as SoStatus,

      /* ---------- Ordered ---------- */
      @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
      soi.Quantity                        as OrderedQuantity,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      soi.NetAmount                       as OrderedNetAmount,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      soi.VatAmount                       as OrderedVatAmount,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      soi.GrossAmount                     as OrderedGrossAmount,

      /* ---------- Issued (posted goods issues) ---------- */
      @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
      cast( coalesce( cast( iss.IssuedQuantity as abap.dec( 23, 3 ) ),
                      cast( 0 as abap.dec( 23, 3 ) ) ) as zmerp_quantity )
                                          as IssuedQuantity,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      cast( coalesce( cast( iss.IssuedNetAmount as abap.dec( 25, 2 ) ),
                      cast( 0 as abap.dec( 25, 2 ) ) ) as zmerp_net_amount )
                                          as IssuedNetAmount,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      cast( coalesce( cast( iss.IssuedVatAmount as abap.dec( 25, 2 ) ),
                      cast( 0 as abap.dec( 25, 2 ) ) ) as zmerp_vat_amount )
                                          as IssuedVatAmount,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      cast( coalesce( cast( iss.IssuedGrossAmount as abap.dec( 25, 2 ) ),
                      cast( 0 as abap.dec( 25, 2 ) ) ) as zmerp_gross_amount )
                                          as IssuedGrossAmount,

      /* ---------- Open (ordered - issued) ---------- */
      @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
      cast( cast( soi.Quantity as abap.dec( 23, 3 ) )
            - coalesce( cast( iss.IssuedQuantity as abap.dec( 23, 3 ) ),
                        cast( 0 as abap.dec( 23, 3 ) ) ) as zmerp_quantity )
                                          as OpenQuantity,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      cast( cast( soi.NetAmount as abap.dec( 25, 2 ) )
            - coalesce( cast( iss.IssuedNetAmount as abap.dec( 25, 2 ) ),
                        cast( 0 as abap.dec( 25, 2 ) ) ) as zmerp_net_amount )
                                          as OpenNetAmount,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      cast( cast( soi.VatAmount as abap.dec( 25, 2 ) )
            - coalesce( cast( iss.IssuedVatAmount as abap.dec( 25, 2 ) ),
                        cast( 0 as abap.dec( 25, 2 ) ) ) as zmerp_vat_amount )
                                          as OpenVatAmount,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      cast( cast( soi.GrossAmount as abap.dec( 25, 2 ) )
            - coalesce( cast( iss.IssuedGrossAmount as abap.dec( 25, 2 ) ),
                        cast( 0 as abap.dec( 25, 2 ) ) ) as zmerp_gross_amount )
                                          as OpenGrossAmount,

      /* ---------- Issue status: N = not issued, P = partial, C = complete, O = over-issued ---------- */
      cast( case
              when iss.SoItemUUID is null            then 'N'
              when iss.IssuedQuantity < cast( soi.Quantity as abap.dec( 23, 3 ) ) then 'P'
              when iss.IssuedQuantity = cast( soi.Quantity as abap.dec( 23, 3 ) ) then 'C'
              else 'O'
            end as abap.char( 1 ) )       as IssueStatus,

      /* Associations */
      _SalesOrder,
      _Item
}
