@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Item Group Value Help'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true

define view entity ZMERP_I_ITEM_GROUP_VH
  as select from ZMERP_R_ITEM_GROUP
{
  @Search.defaultSearchElement: true
  @Search.ranking: #HIGH
  key ItemGroupCode,

  @Search.defaultSearchElement: true
  @Search.ranking: #HIGH
  @Search.fuzzinessThreshold: 0.7
  Description,

  @ObjectModel.text.element: [ 'DefaultVATRateDescription' ]
  @UI.textArrangement: #TEXT_ONLY  
  DefaultVatCode,  
  _DefaultVATRate.Description as DefaultVATRateDescription
}

where
  IsBlocked = ''
