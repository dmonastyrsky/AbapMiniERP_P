@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Business Partner Value Help'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true

define view entity ZMERP_I_BUS_PARTNER_VH
  as select from ZMERP_R_BUS_PARTNER
{
      @Search.defaultSearchElement: true
      @Search.ranking: #HIGH
  key PartnerCode,

      @Search.defaultSearchElement: true
      @Search.ranking: #HIGH
      @Search.fuzzinessThreshold: 0.7
      PartnerName,

      IsCustomer,      
      IsSupplier,

      @Search.defaultSearchElement: true
      TaxNumber,

      @ObjectModel.text.element: [ 'CountryName' ]
      @UI.textArrangement: #TEXT_FIRST
      Country,
      _CountryText.CountryName as CountryName
}

where
  IsBlocked = ''
