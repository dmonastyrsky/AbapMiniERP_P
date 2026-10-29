@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Purchase Order Status Text'
@ObjectModel.dataCategory: #TEXT

define view entity ZMERP_I_PO_STATUS
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZMERP_PO_STATUS' )
{
  @EndUserText.label: 'Status Code'
  key value_low as Status,

  @Semantics.text: true
  @EndUserText.label: 'Status Description'
  text          as StatusText
}
where language = $session.system_language
