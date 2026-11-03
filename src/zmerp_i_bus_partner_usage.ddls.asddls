@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Business Partner Usage Dependencies'
@Metadata.ignorePropagatedAnnotations: true

// UsedAsSupplier: purchasing documents (PO, GR); UsedAsCustomer: sales documents (to be added)

define view entity ZMERP_I_BUS_PARTNER_USAGE
  as select from ZMERP_R_PURCHASEORDER
{
  key BusinessPartnerCode                               as PartnerCode,
  key DocumentUUID                                      as DocumentUUID,
  key cast( bintohex( DocumentUUID ) as abap.char(40) ) as RefEntityKey,
  key cast( 'Purchase Order' as zmerp_entity_name )     as UsedInEntity,
      cast( 'X' as abap_boolean preserving type )       as UsedAsSupplier,
      cast( ' ' as abap_boolean preserving type )       as UsedAsCustomer,
      cast( 'X' as abap_boolean preserving type )       as IsDocument
}
where BusinessPartnerCode is not initial

union all select from ZMERP_R_GOODSRECEIPT
{
  key BusinessPartnerCode                               as PartnerCode,
  key DocumentUUID                                      as DocumentUUID,
  key cast( bintohex( DocumentUUID ) as abap.char(40) ) as RefEntityKey,
  key cast( 'Goods Receipt' as zmerp_entity_name )      as UsedInEntity,
      cast( 'X' as abap_boolean preserving type )       as UsedAsSupplier,
      cast( ' ' as abap_boolean preserving type )       as UsedAsCustomer,
      cast( 'X' as abap_boolean preserving type )       as IsDocument
}
where BusinessPartnerCode is not initial
