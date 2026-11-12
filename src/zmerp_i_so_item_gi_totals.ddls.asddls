@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'SO Item: Posted Goods Issue Totals'
@Metadata.ignorePropagatedAnnotations: true

// One row per sales order item. Sums are plain decimals, so they need no unit or
// currency reference and the view does not group by them (SO lines take both from the
// SO item and cannot change them). ZMERP_I_SO_PROGRESS gives them back their types.
define view entity ZMERP_I_SO_ITEM_GI_TOTALS
  as select from ZMERP_R_GOODSISSUEITM as gii
    inner join   ZMERP_R_GOODSISSUE    as gih on gih.DocumentUUID = gii.HeaderUUID
{
  key gii.SoItemReferenceUUID                              as SoItemUUID,
      sum( cast( gii.Quantity    as abap.dec( 23, 3 ) ) )  as IssuedQuantity,
      sum( cast( gii.NetAmount   as abap.dec( 25, 2 ) ) )  as IssuedNetAmount,
      sum( cast( gii.VatAmount   as abap.dec( 25, 2 ) ) )  as IssuedVatAmount,
      sum( cast( gii.GrossAmount as abap.dec( 25, 2 ) ) )  as IssuedGrossAmount,
      count( * )                                           as IssueItemCount
}
// 'P' = posted (ZCL_MERP_DOC_GI_LIFECYCLE=>c_status_posted)
where gih.Status = 'P'
  and gii.SoItemReferenceUUID is not initial
group by gii.SoItemReferenceUUID
