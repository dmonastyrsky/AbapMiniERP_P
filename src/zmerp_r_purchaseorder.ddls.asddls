@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Purchase Order Root Entity'
@ObjectModel.sapObjectNodeType.name: 'ZMERP_PO_HDR'

define root view entity ZMERP_R_PURCHASEORDER
  as select from zmerp_po_hdr
  composition [0..*] of ZMERP_R_PURCHASEORDERITM as _Items
  association [0..1] to ZMERP_R_COMPANY_CODE     as _CompanyCode     on $projection.CompanyCode = _CompanyCode.CompanyCode
  association [0..1] to ZMERP_R_WAREHOUSE        as _Warehouse       on $projection.WarehouseCode = _Warehouse.WarehouseCode
  association [0..1] to ZMERP_R_BUS_PARTNER      as _BusinessPartner on $projection.BusinessPartnerCode = _BusinessPartner.PartnerCode
  association [0..1] to ZMERP_I_PO_STATUS_VH     as _Status          on $projection.Status = _Status.Status
                                                                    and _Status.Language = $session.system_language
  association [0..1] to I_Currency               as _Currency        on $projection.CurrencyCode = _Currency.Currency
{
  key document_uuid         as DocumentUUID,

      document_number       as DocumentNumber,
      document_date         as DocumentDate,
      posting_date          as PostingDate,

      @ObjectModel.foreignKey.association: '_CompanyCode'
      company_code          as CompanyCode,

      @ObjectModel.foreignKey.association: '_Warehouse'
      warehouse_code        as WarehouseCode,

      @ObjectModel.foreignKey.association: '_BusinessPartner'
      business_partner_code as BusinessPartnerCode,

      @ObjectModel.foreignKey.association: '_Currency'
      currency_code         as CurrencyCode,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      total_net_amount      as TotalNetAmount,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      total_gross_amount    as TotalGrossAmount,

      responsible_person    as ResponsiblePerson,
      remarks               as Remarks,

      supplier_reference    as SupplierReference,
      delivery_date         as DeliveryDate,

      @ObjectModel.foreignKey.association: '_Status'
      status                as Status,

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

      _Items,
      _CompanyCode,
      _Warehouse,
      _BusinessPartner,
      _Status,
      _Currency
}
