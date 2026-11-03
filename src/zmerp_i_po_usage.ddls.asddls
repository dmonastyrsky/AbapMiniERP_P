@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Purchase Order Usage Dependencies'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZMERP_I_PO_USAGE
  as select from ZMERP_R_GOODSRECEIPT
{
  key PoReferenceUUID                                  as DocumentUUID,
  key cast( bintohex( DocumentUUID ) as abap.char(40) ) as RefEntityKey,
  key cast( 'Goods Receipt' as zmerp_entity_name )     as UsedInEntity
}
where PoReferenceUUID is not initial
