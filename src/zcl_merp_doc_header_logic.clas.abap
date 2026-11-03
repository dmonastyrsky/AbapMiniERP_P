"! Shared business logic for document headers (Purchase Order, Goods Receipt, sales documents, ...):
"! defaulting and derivation of header fields of the common header structure ZMERP_S_DOC_HDR_COMMON.
"! Pure business logic without RAP dependencies (same idea as ZCL_MERP_DOC_ITEM_LOGIC): the caller
"! (behavior handler) reads from and writes to the transactional buffer.
"! Validations and messages are NOT part of this class, they stay in the handler of each document.
CLASS zcl_merp_doc_header_logic DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Document type, selects the number range (add the sales documents here)
    CONSTANTS: BEGIN OF c_doc_type,
                 purchase_order TYPE c LENGTH 2 VALUE 'PO',
                 goods_receipt  TYPE c LENGTH 2 VALUE 'GR',
               END OF c_doc_type.

    "! Header data in the shape of the common header structure. Component names match the header entities,
    "! so the caller fills it with CORRESPONDING ... MAPPING HeaderUUID = DocumentUUID IsDraft = %is_draft
    "! (IsDraft is the only technical field: pass-through of %is_draft, needed to map results back).
    "! Only the fields read by the caller are filled, all other components stay initial.
    TYPES: BEGIN OF ty_header,
             HeaderUUID     TYPE sysuuid_x16,
             IsDraft        TYPE abp_behv_flag,
             DocumentNumber TYPE zmerp_doc_num,
             DocumentDate   TYPE zmerp_doc_date,
             PostingDate    TYPE zmerp_posting_date,
             CompanyCode    TYPE zmerp_company_code,
             WarehouseCode  TYPE zmerp_warehouse_code,
             CurrencyCode   TYPE zmerp_currency_code,
             Status         TYPE c LENGTH 1,
           END OF ty_header,
           tt_headers TYPE STANDARD TABLE OF ty_header WITH EMPTY KEY.

    "! Allocated document number of a header
    TYPES: BEGIN OF ty_number,
             HeaderUUID     TYPE sysuuid_x16,
             IsDraft        TYPE abp_behv_flag,
             DocumentNumber TYPE zmerp_doc_num,
           END OF ty_number,
           tt_numbers TYPE STANDARD TABLE OF ty_number WITH EMPTY KEY.

    "! Header for which no document number could be allocated (PREVIOUS = cause, may be initial)
    TYPES: BEGIN OF ty_number_failed,
             HeaderUUID TYPE sysuuid_x16,
             IsDraft    TYPE abp_behv_flag,
             previous   TYPE REF TO cx_root,
           END OF ty_number_failed,
           tt_numbers_failed TYPE STANDARD TABLE OF ty_number_failed WITH EMPTY KEY.

    "! @parameter io_company_selector   | if not supplied, the standard selector is used (inject a test double in unit tests)
    "! @parameter io_warehouse_selector | if not supplied, the standard selector is used
    METHODS constructor
      IMPORTING io_company_selector   TYPE REF TO zif_merp_md_comp_code_sel OPTIONAL
                io_warehouse_selector TYPE REF TO zif_merp_md_warehouse_sel OPTIONAL.

    "! Defaults on creation: document date (today), posting date (= document date), initial status
    "! @parameter it_headers        | Headers with DocumentDate, PostingDate, Status
    "! @parameter iv_initial_status | Status of a new document (differs per document type)
    "! @parameter rt_changed        | Only the headers where at least one default was set (with the new values)
    METHODS get_defaults
      IMPORTING it_headers        TYPE tt_headers
                iv_initial_status TYPE c
      RETURNING VALUE(rt_changed) TYPE tt_headers.

    "! Company code changed: document currency follows the company currency,
    "! a warehouse that does not belong to the company code is cleared
    "! @parameter it_headers | Headers with CompanyCode, CurrencyCode, WarehouseCode
    "! @parameter rt_changed | Only the headers where CurrencyCode or WarehouseCode changed (with the new values)
    METHODS derive_on_company_code
      IMPORTING it_headers        TYPE tt_headers
      RETURNING VALUE(rt_changed) TYPE tt_headers.

    "! Document date changed: the posting date must not precede it (aligned to the document date if it does)
    "! @parameter it_headers | Headers with DocumentDate, PostingDate
    "! @parameter rt_changed | Only the headers where PostingDate changed (with the new value)
    METHODS derive_posting_date
      IMPORTING it_headers        TYPE tt_headers
      RETURNING VALUE(rt_changed) TYPE tt_headers.

    "! Allocates document numbers in bulk (one number range call per company code).
    "! Headers that already have a number or have no company code are ignored.
    "! @parameter it_headers  | Headers with DocumentNumber, CompanyCode
    "! @parameter iv_doc_type | see C_DOC_TYPE
    "! @parameter et_numbers  | Allocated numbers
    "! @parameter et_failed   | Headers without number (the caller reports the message of its own exception class)
    METHODS assign_numbers
      IMPORTING it_headers  TYPE tt_headers
                iv_doc_type TYPE c
      EXPORTING et_numbers  TYPE tt_numbers
                et_failed   TYPE tt_numbers_failed.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mo_company_selector   TYPE REF TO zif_merp_md_comp_code_sel.
    DATA mo_warehouse_selector TYPE REF TO zif_merp_md_warehouse_sel.

    "! Next document numbers of the number range of the document type
    METHODS get_numbers
      IMPORTING iv_doc_type     TYPE c
                iv_company_code TYPE zmerp_company_code
                iv_count        TYPE i
      RETURNING VALUE(rt_codes) TYPE string_table
      RAISING   cx_number_ranges.
ENDCLASS.


CLASS zcl_merp_doc_header_logic IMPLEMENTATION.

  METHOD constructor.
    IF io_company_selector IS BOUND.
      mo_company_selector = io_company_selector.
    ELSE.
      mo_company_selector = NEW zcl_merp_md_comp_code_sel( ).
    ENDIF.

    IF io_warehouse_selector IS BOUND.
      mo_warehouse_selector = io_warehouse_selector.
    ELSE.
      mo_warehouse_selector = NEW zcl_merp_md_warehouse_sel( ).
    ENDIF.
  ENDMETHOD.

  METHOD get_defaults.
    IF it_headers IS INITIAL.
      RETURN.
    ENDIF.

    DATA(ls_generic_defaults) = zcl_merp_doc_util=>get_generic_header_defaults( ).

    LOOP AT it_headers INTO DATA(ls_original).
      DATA(ls_header) = ls_original.

      IF ls_header-DocumentDate IS INITIAL.
        ls_header-DocumentDate = ls_generic_defaults-document_date.
      ENDIF.

      IF ls_header-PostingDate IS INITIAL.
        ls_header-PostingDate = ls_header-DocumentDate.
      ENDIF.

      IF ls_header-Status IS INITIAL.
        ls_header-Status = iv_initial_status.
      ENDIF.

      " Return only headers that really changed
      IF ls_header <> ls_original.
        APPEND ls_header TO rt_changed.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD derive_on_company_code.
    IF it_headers IS INITIAL.
      RETURN.
    ENDIF.

    " Bulk select master data (the selectors cleanse keys themselves: initial values and duplicates are ignored)
    DATA(lt_companies) = mo_company_selector->read_companies(
      VALUE #( FOR header IN it_headers ( CompanyCode = header-CompanyCode ) ) ).

    DATA(lt_warehouses) = mo_warehouse_selector->read_warehouses(
      VALUE #( FOR header IN it_headers ( WarehouseCode = header-WarehouseCode ) ) ).

    LOOP AT it_headers INTO DATA(ls_original).
      DATA(ls_header) = ls_original.

      IF ls_header-CompanyCode IS NOT INITIAL.
        " Document currency follows the company code currency
        ASSIGN lt_companies[ CompanyCode = ls_header-CompanyCode ] TO FIELD-SYMBOL(<company>).
        IF sy-subrc = 0 AND <company>-CurrencyCode IS NOT INITIAL.
          ls_header-CurrencyCode = <company>-CurrencyCode.
        ENDIF.

        " Reset the warehouse if it does not belong to the selected company code
        IF ls_header-WarehouseCode IS NOT INITIAL.
          ASSIGN lt_warehouses[ WarehouseCode = ls_header-WarehouseCode ] TO FIELD-SYMBOL(<warehouse>).
          IF sy-subrc <> 0 OR <warehouse>-CompanyCode <> ls_header-CompanyCode.
            CLEAR ls_header-WarehouseCode.
          ENDIF.
        ENDIF.
      ENDIF.

      " Return only headers that really changed
      IF ls_header <> ls_original.
        APPEND ls_header TO rt_changed.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD derive_posting_date.
    LOOP AT it_headers INTO DATA(ls_original).
      DATA(ls_header) = ls_original.

      IF ls_header-DocumentDate IS NOT INITIAL
         AND ls_header-PostingDate IS NOT INITIAL
         AND zcl_merp_doc_validator=>is_posting_date_valid( iv_doc_date  = ls_header-DocumentDate
                                                            iv_post_date = ls_header-PostingDate ) = abap_false.
        ls_header-PostingDate = ls_header-DocumentDate.
      ENDIF.

      " Return only headers that really changed
      IF ls_header <> ls_original.
        APPEND ls_header TO rt_changed.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD assign_numbers.
    DATA lx_error TYPE REF TO cx_number_ranges.
    DATA lt_codes TYPE string_table.

    CLEAR: et_numbers, et_failed.

    " Only headers without number and with company code (the number range depends on it)
    DATA(lt_todo) = it_headers.
    DELETE lt_todo WHERE DocumentNumber IS NOT INITIAL OR CompanyCode IS INITIAL.
    IF lt_todo IS INITIAL.
      RETURN.
    ENDIF.

    " One number range call per company code
    DATA(lt_companies) = lt_todo.
    SORT lt_companies BY CompanyCode.
    DELETE ADJACENT DUPLICATES FROM lt_companies COMPARING CompanyCode.

    LOOP AT lt_companies INTO DATA(ls_company).
      DATA(lt_company_headers) = VALUE tt_headers(
        FOR header IN lt_todo WHERE ( CompanyCode = ls_company-CompanyCode ) ( header ) ).

      CLEAR: lx_error, lt_codes.
      TRY.
          lt_codes = get_numbers( iv_doc_type     = iv_doc_type
                                  iv_company_code = ls_company-CompanyCode
                                  iv_count        = lines( lt_company_headers ) ).
        CATCH cx_number_ranges INTO lx_error.
          CLEAR lt_codes.
      ENDTRY.

      " Map the allocated codes back to the headers in the order of the allocation
      LOOP AT lt_company_headers INTO DATA(ls_header).
        READ TABLE lt_codes INDEX sy-tabix INTO DATA(lv_code).

        IF sy-subrc = 0 AND lv_code IS NOT INITIAL.
          APPEND VALUE #( HeaderUUID     = ls_header-HeaderUUID
                          IsDraft        = ls_header-IsDraft
                          DocumentNumber = CONV #( lv_code ) ) TO et_numbers.
        ELSE.
          APPEND VALUE #( HeaderUUID = ls_header-HeaderUUID
                          IsDraft    = ls_header-IsDraft
                          previous   = lx_error ) TO et_failed.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_numbers.
    CASE iv_doc_type.
      WHEN c_doc_type-purchase_order.
        rt_codes = zcl_merp_num_range_util=>get_next_po_numbers_nro( iv_company_code = iv_company_code
                                                                     iv_count        = iv_count ).
      WHEN c_doc_type-goods_receipt.
        rt_codes = zcl_merp_num_range_util=>get_next_gr_numbers_nro( iv_company_code = iv_company_code
                                                                     iv_count        = iv_count ).
    ENDCASE.
  ENDMETHOD.

ENDCLASS.

