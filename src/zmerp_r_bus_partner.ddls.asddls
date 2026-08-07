@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Business Partner Root Entity'
@ObjectModel.sapObjectNodeType.name: 'ZMERP_BUS_PART'
@Metadata.ignorePropagatedAnnotations: true

define root view entity ZMERP_R_BUS_PARTNER
  as select from zmerp_bus_part
  association [0..1] to I_CountryText as _CountryText on $projection.Country   = _CountryText.Country
                                                         and _CountryText.Language = $session.system_language
  association [0..1] to I_Country     as _Country     on $projection.Country   = _Country.Country
{
  key partner_code          as PartnerCode,
      partner_name          as PartnerName,
      is_customer           as IsCustomer,
      is_supplier           as IsSupplier,      
      tax_number            as TaxNumber,
      address               as Address,
      city                  as City,

      @ObjectModel.foreignKey.association: '_Country'
      country               as Country,
      phone                 as Phone,
      email                 as Email,
      
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

      _CountryText,
      _Country
}
