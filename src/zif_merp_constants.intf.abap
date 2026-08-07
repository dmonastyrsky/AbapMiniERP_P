"! Global system constants for Mini ERP application
INTERFACE zif_merp_constants
  PUBLIC.

  " Entity Metadata Schema Definition
  TYPES:
    BEGIN OF ty_entity_metadata,
      prefix        TYPE string,
      length        TYPE i,
      number_object TYPE cl_numberrange_runtime=>nr_object,
      table_db      TYPE string,
      field_db      TYPE string,
      table_draft   TYPE string,
      field_draft   TYPE string,
      cds_view      TYPE string,
    END OF ty_entity_metadata.

  CONSTANTS:
    " Business Partners Metadata
    BEGIN OF c_bp,
      prefix        TYPE string VALUE '',
      length        TYPE i VALUE 5,
      number_object TYPE cl_numberrange_runtime=>nr_object VALUE 'ZNR_BP',
      table_db      TYPE string VALUE 'ZMERP_BUS_PART',
      field_db      TYPE string VALUE 'PARTNER_CODE',
      table_draft   TYPE string VALUE 'ZMERP_BUS_PART_D',
      field_draft   TYPE string VALUE 'PARTNERCODE',
      cds_view      TYPE string VALUE 'ZMERP_R_BUS_PARTNER',
    END OF c_bp,

    " Company Codes Metadata
    BEGIN OF c_comp,
      prefix        TYPE string VALUE '',
      length        TYPE i VALUE 4,
      number_object TYPE cl_numberrange_runtime=>nr_object VALUE '',
      table_db      TYPE string VALUE 'ZMERP_COMP_CODE',
      field_db      TYPE string VALUE 'COMPANY_CODE',
      table_draft   TYPE string VALUE 'ZMERP_COMP_D',
      field_draft   TYPE string VALUE 'COMPANYCODE',
      cds_view      TYPE string VALUE 'ZMERP_R_COMPANY_CODE',
    END OF c_comp,

    " Items Metadata
    BEGIN OF c_item,
      prefix        TYPE string VALUE '',
      length        TYPE i VALUE 5,
      number_object TYPE cl_numberrange_runtime=>nr_object VALUE 'ZNR_ITEM',
      table_db      TYPE string VALUE 'ZMERP_ITEM',
      field_db      TYPE string VALUE 'ITEM_CODE',
      table_draft   TYPE string VALUE 'ZMERP_ITEM_D',
      field_draft   TYPE string VALUE 'ITEMCODE',
      cds_view      TYPE string VALUE 'ZMERP_R_ITEM',
    END OF c_item,

    " Item Groups Metadata
    BEGIN OF c_ig,
      prefix        TYPE string VALUE '',
      length        TYPE i VALUE 5,
      number_object TYPE cl_numberrange_runtime=>nr_object VALUE 'ZNR_IG',
      table_db      TYPE string VALUE 'ZMERP_ITEM_GROUP',
      field_db      TYPE string VALUE 'ITEM_GROUP_CODE',
      table_draft   TYPE string VALUE 'ZMERP_ITEM_GRP_D',
      field_draft   TYPE string VALUE 'ITEMGROUPCODE',
      cds_view      TYPE string VALUE 'ZMERP_R_ITEM_GROUP',
    END OF c_ig,

    " VAT Rates Metadata
    BEGIN OF c_vat,
      prefix        TYPE string VALUE 'V',
      length        TYPE i VALUE 4,
      number_object TYPE cl_numberrange_runtime=>nr_object VALUE 'ZNR_VAT',
      table_db      TYPE string VALUE 'ZMERP_VAT_RATE',
      field_db      TYPE string VALUE 'VAT_CODE',
      table_draft   TYPE string VALUE 'ZMERP_VATR_D',
      field_draft   TYPE string VALUE 'VATCODE',
      cds_view      TYPE string VALUE 'ZMERP_R_VAT_RATE',
    END OF c_vat,

    " Warehouses Metadata
    BEGIN OF c_wh,
      prefix        TYPE string VALUE 'WH',
      length        TYPE i VALUE 5,
      number_object TYPE cl_numberrange_runtime=>nr_object VALUE 'ZNR_WHSE',
      table_db      TYPE string VALUE 'ZMERP_WAREHOUSE',
      field_db      TYPE string VALUE 'WAREHOUSE_CODE',
      table_draft   TYPE string VALUE 'ZMERP_WHSE_D',
      field_draft   TYPE string VALUE 'WAREHOUSECODE',
      cds_view      TYPE string VALUE 'ZMERP_R_WAREHOUSE',
    END OF c_wh.

ENDINTERFACE.
