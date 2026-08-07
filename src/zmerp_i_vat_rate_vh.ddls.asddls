@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VAT Rate Value Help'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true
@ObjectModel.resultSet.sizeCategory: #XS

define view entity ZMERP_I_VAT_RATE_VH
  as select from ZMERP_R_VAT_RATE
{
      @UI.textArrangement: #TEXT_ONLY
      @Search.defaultSearchElement: true
      @Search.ranking: #HIGH
  key VatCode,

      @Search.defaultSearchElement: true
      @Search.ranking: #HIGH
      @Search.fuzzinessThreshold: 0.7
      Description,

      Percentage
}

where
  IsBlocked = ''
