@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order Usage Dependencies'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZMERP_I_SO_USAGE
  as select from ZMERP_R_GOODSISSUE
{
  key SoReferenceUUID                                   as DocumentUUID,
  key cast( bintohex( DocumentUUID ) as abap.char(40) ) as RefEntityKey,
  key cast( 'Goods Issue' as zmerp_entity_name )        as UsedInEntity
}
where SoReferenceUUID is not initial
