@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Stock Transfer Root Entity'
@ObjectModel.sapObjectNodeType.name: 'ZMERP_ST_HDR'

define root view entity ZMERP_R_STOCKTRANSFER
  as select from zmerp_st_hdr
  composition [0..*] of ZMERP_R_STOCKTRANSFERITM as _Items
  association [0..1] to ZMERP_R_COMPANY_CODE as _CompanyCode        on $projection.CompanyCode = _CompanyCode.CompanyCode
  association [0..1] to ZMERP_R_WAREHOUSE    as _Warehouse          on $projection.WarehouseCode = _Warehouse.WarehouseCode
  association [0..1] to ZMERP_R_WAREHOUSE    as _ReceivingWarehouse on $projection.ReceivingWarehouseCode = _ReceivingWarehouse.WarehouseCode
  association [0..1] to ZMERP_I_ST_STATUS_VH as _Status             on $projection.Status = _Status.Status
                                                                   and _Status.Language = $session.system_language
{
  key document_uuid            as DocumentUUID,

      document_number          as DocumentNumber,
      document_date            as DocumentDate,
      posting_date             as PostingDate,

      @ObjectModel.foreignKey.association: '_CompanyCode'
      company_code             as CompanyCode,

      @ObjectModel.foreignKey.association: '_Warehouse'
      warehouse_code           as WarehouseCode,

      responsible_person       as ResponsiblePerson,
      remarks                  as Remarks,

      @ObjectModel.foreignKey.association: '_ReceivingWarehouse'
      receiving_warehouse_code as ReceivingWarehouseCode,

      @ObjectModel.foreignKey.association: '_Status'
      status                   as Status,

      @Semantics.user.createdBy: true
      created_by               as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at               as CreatedAt,
      @Semantics.user.localInstanceLastChangedBy: true
      local_last_changed_by    as LocalLastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at    as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at          as LastChangedAt,

      _Items,
      _CompanyCode,
      _Warehouse,
      _ReceivingWarehouse,
      _Status
}
