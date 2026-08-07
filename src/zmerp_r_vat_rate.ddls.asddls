@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VAT Rate Root Entity'
@ObjectModel.sapObjectNodeType.name: 'ZMERP_VAT_RATE'
@Metadata.ignorePropagatedAnnotations: true

define root view entity ZMERP_R_VAT_RATE
  as select from zmerp_vat_rate
{
  key vat_code              as VatCode,

      description           as Description,
      percentage            as Percentage,
      
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
      last_changed_at       as LastChangedAt
}
