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
    END OF ty_entity_metadata,

    " Global table types for Master Data (MD) components
    ty_md_bp_tt       TYPE STANDARD TABLE OF zmerp_bus_part WITH EMPTY KEY,
    ty_md_comp_tt     TYPE STANDARD TABLE OF zmerp_comp_code WITH EMPTY KEY,
    ty_md_item_tt     TYPE STANDARD TABLE OF zmerp_item WITH EMPTY KEY,
    ty_md_itemgr_tt   TYPE STANDARD TABLE OF zmerp_item_group WITH EMPTY KEY,
    ty_md_vat_tt      TYPE STANDARD TABLE OF zmerp_vat_rate WITH EMPTY KEY,
    ty_md_wh_tt       TYPE STANDARD TABLE OF zmerp_warehouse WITH EMPTY KEY.

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
    END OF c_wh,

    " Purchase Orders Metadata
    BEGIN OF c_po,
      prefix        TYPE string VALUE '',
      length        TYPE i VALUE 10,
      number_object TYPE cl_numberrange_runtime=>nr_object VALUE 'ZNR_PURORD',
      table_db      TYPE string VALUE 'ZMERP_PO_HDR',
      field_db      TYPE string VALUE 'DOCUMENT_NUMBER',
      table_draft   TYPE string VALUE 'ZMERP_PO_HDR_D',
      field_draft   TYPE string VALUE 'DOCUMENTNUMBER',
    END OF c_po,

    " Purchase Order Items Metadata
    BEGIN OF c_po_itm,
      prefix        TYPE string VALUE '',
      length        TYPE i VALUE 0,
      number_object TYPE cl_numberrange_runtime=>nr_object VALUE '',
      table_db      TYPE string VALUE 'ZMERP_PO_ITM',
      field_db      TYPE string VALUE 'ITEM_UUID',
      table_draft   TYPE string VALUE 'ZMERP_PO_ITM_D',
      field_draft   TYPE string VALUE 'ITEMUUID',
    END OF c_po_itm,

    " Goods Receipts Metadata
    BEGIN OF c_gr,
      prefix        TYPE string VALUE '',
      length        TYPE i VALUE 10,
      number_object TYPE cl_numberrange_runtime=>nr_object VALUE 'ZNR_GDSREC',
      table_db      TYPE string VALUE 'ZMERP_GR_HDR',
      field_db      TYPE string VALUE 'DOCUMENT_NUMBER',
      table_draft   TYPE string VALUE 'ZMERP_GR_HDR_D',
      field_draft   TYPE string VALUE 'DOCUMENTNUMBER',
    END OF c_gr,

    " Goods Receipt Items Metadata
    BEGIN OF c_gr_itm,
      prefix        TYPE string VALUE '',
      length        TYPE i VALUE 0,
      number_object TYPE cl_numberrange_runtime=>nr_object VALUE '',
      table_db      TYPE string VALUE 'ZMERP_GR_ITM',
      field_db      TYPE string VALUE 'ITEM_UUID',
      table_draft   TYPE string VALUE 'ZMERP_GR_ITM_D',
      field_draft   TYPE string VALUE 'ITEMUUID',
    END OF c_gr_itm,

    " Stock Movements Metadata (journal: no draft, no number range)
    BEGIN OF c_stock_mov,
      prefix        TYPE string VALUE '',
      length        TYPE i VALUE 0,
      number_object TYPE cl_numberrange_runtime=>nr_object VALUE '',
      table_db      TYPE string VALUE 'ZMERP_STOCK_MOV',
      field_db      TYPE string VALUE 'MOVEMENT_UUID',
      table_draft   TYPE string VALUE '',
      field_draft   TYPE string VALUE '',
    END OF c_stock_mov,

    " Item types (domain ZMERP_ITEM_TYPE): only products are kept in stock
    BEGIN OF c_item_type,
      product TYPE zmerp_item_type VALUE 'P',
      service TYPE zmerp_item_type VALUE 'S',
    END OF c_item_type.

ENDINTERFACE.
