@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'PO Item: Posted Goods Receipt Totals'
@Metadata.ignorePropagatedAnnotations: true

// One row per purchase order item. Sums are plain decimals, so they need no unit or
// currency reference and the view does not group by them (PO lines take both from the
// PO item and cannot change them). ZMERP_I_PO_PROGRESS gives them back their types.
define view entity ZMERP_I_PO_ITEM_GR_TOTALS
  as select from ZMERP_R_GOODSRECEIPTITM as gri
    inner join   ZMERP_R_GOODSRECEIPT    as grh on grh.DocumentUUID = gri.HeaderUUID
{
  key gri.PoItemReferenceUUID                              as PoItemUUID,

      sum( cast( gri.Quantity    as abap.dec( 23, 3 ) ) )  as ReceivedQuantity,
      sum( cast( gri.NetAmount   as abap.dec( 25, 2 ) ) )  as ReceivedNetAmount,
      sum( cast( gri.VatAmount   as abap.dec( 25, 2 ) ) )  as ReceivedVatAmount,
      sum( cast( gri.GrossAmount as abap.dec( 25, 2 ) ) )  as ReceivedGrossAmount,

      count( * )                                           as ReceiptItemCount
}
// 'P' = posted (ZCL_MERP_DOC_GR_LIFECYCLE=>c_status_posted)
where grh.Status = 'P'
  and gri.PoItemReferenceUUID is not initial
group by gri.PoItemReferenceUUID
