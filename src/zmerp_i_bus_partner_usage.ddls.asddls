@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Business Partner Usage Dependencies'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZMERP_I_BUS_PARTNER_USAGE
  as select from ZMERP_R_PURCHASEORDER
{
  key BusinessPartnerCode                               as PartnerCode,
  key DocumentUUID                                      as DocumentUUID,
  key cast( bintohex( DocumentUUID ) as abap.char(40) ) as RefEntityKey,
  key cast( 'Purchase Order' as zmerp_entity_name )     as UsedInEntity
}
where BusinessPartnerCode is not initial
