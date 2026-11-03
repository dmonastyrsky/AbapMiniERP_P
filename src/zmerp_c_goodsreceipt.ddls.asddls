@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Goods Receipt Projection View'
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: ['DocumentNumber']

define root view entity ZMERP_C_GOODSRECEIPT
  provider contract transactional_query
  as projection on ZMERP_R_GOODSRECEIPT
{

  @ObjectModel.text.element: [ 'DocumentNumber' ]
  key DocumentUUID,

      @Search.defaultSearchElement: true
      @Search.ranking: #HIGH
      DocumentNumber,

      DocumentDate,
      PostingDate,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMERP_I_COMPANY_CODE_VH', element: 'CompanyCode' }, useForValidation: true }]
      CompanyCode,

      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZMERP_I_WAREHOUSE_VH', element: 'WarehouseCode' },
        additionalBinding: [{ localElement: 'CompanyCode', element: 'CompanyCode', usage: #FILTER_AND_RESULT }],
        useForValidation: true
      }]
      WarehouseCode,

      @Consumption.valueHelpDefinition: [{ 
        entity: { name: 'ZMERP_I_BUS_PARTNER_VH', element: 'PartnerCode' },
        additionalBinding: [{ element: 'IsSupplier', localConstant: 'X', usage: #FILTER_AND_RESULT }],
        useForValidation: true 
      }]
      BusinessPartnerCode,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_CurrencyStdVH', element: 'Currency' }, useForValidation: true }]
      CurrencyCode,

      TotalNetAmount,
      TotalGrossAmount,

      ResponsiblePerson,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      Remarks,

      @ObjectModel.text.element: [ 'PoDocumentNumber' ]
      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZMERP_I_PO_VH', element: 'DocumentUUID' },
        additionalBinding: [
          { localElement: 'CompanyCode',         element: 'CompanyCode',         usage: #FILTER_AND_RESULT },
          { localElement: 'WarehouseCode',       element: 'WarehouseCode',       usage: #FILTER_AND_RESULT },
          { localElement: 'BusinessPartnerCode', element: 'BusinessPartnerCode', usage: #FILTER_AND_RESULT },
          { localConstant: 'X',                  element: 'CanReceiveGoods',     usage: #FILTER }
        ],
        useForValidation: true
      }]
      PoReferenceUUID,

      @EndUserText.label: 'Purchase Order Number'
      _PurchaseOrder.DocumentNumber as PoDocumentNumber,

      @Search.defaultSearchElement: true
      SupplierReference,

      @ObjectModel.text.element: ['StatusDescription']
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMERP_I_GR_STATUS_VH', element: 'Status' }, useForValidation: true }]
      Status,

      @EndUserText.label: 'Status Description'
      _Status.Description as StatusDescription,

      CreatedBy,
      CreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      _Items           : redirected to composition child ZMERP_C_GOODSRECEIPTITM,
      _CompanyCode     : redirected to ZMERP_C_COMPANY_CODE,
      _Warehouse       : redirected to ZMERP_C_WAREHOUSE,
      _BusinessPartner : redirected to ZMERP_C_BUS_PARTNER,
      _PurchaseOrder   : redirected to ZMERP_C_PURCHASEORDER,
      _Currency,
      _Status
}
