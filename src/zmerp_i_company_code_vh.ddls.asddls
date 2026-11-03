@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Company Code Value Help'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true

define view entity ZMERP_I_COMPANY_CODE_VH
  as select from ZMERP_R_COMPANY_CODE
{

      @Search.defaultSearchElement: true
      @Search.ranking: #HIGH
  key CompanyCode,

      @Search.defaultSearchElement: true
      @Search.ranking: #HIGH
      @Search.fuzzinessThreshold: 0.7
      CompanyName,
      
      @Search.defaultSearchElement: true
      CompanyPrefix,

      CurrencyCode,
      @ObjectModel.text.element: [ 'CountryName' ]
      @UI.textArrangement: #TEXT_FIRST
      Country,
      _CountryText.CountryName as CountryName
}

where
  IsBlocked = ''
