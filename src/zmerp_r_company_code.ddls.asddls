@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Company Code Root Entity'
@ObjectModel.sapObjectNodeType.name: 'ZMERP_COMP_CODE'
@Metadata.ignorePropagatedAnnotations: true

define root view entity ZMERP_R_COMPANY_CODE
  as select from zmerp_comp_code
  association [0..1] to I_CurrencyText as _CurrencyText on $projection.CurrencyCode = _CurrencyText.Currency
                                                       and _CurrencyText.Language   = $session.system_language
  association [0..1] to I_CountryText  as _CountryText  on $projection.Country      = _CountryText.Country
                                                       and _CountryText.Language    = $session.system_language
  association [0..1] to I_Currency     as _Currency     on $projection.CurrencyCode = _Currency.Currency
  association [0..1] to I_Country      as _Country      on $projection.Country      = _Country.Country  
  
{
      
  key company_code          as CompanyCode,
      company_name          as CompanyName,
      company_prefix        as CompanyPrefix,

      @ObjectModel.foreignKey.association: '_Currency'
      currency_code         as CurrencyCode,

      @ObjectModel.foreignKey.association: '_Country'
      country               as Country,
      
      is_blocked            as IsBlocked,

      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.localInstanceLastChangedBy: true
      local_last_changed_by as LocalLastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,

      _CurrencyText,
      _CountryText,
      _Currency,
      _Country
}
