CLASS zcl_merp_num_range_util DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_merp_constants.

    " Database Max-Search Generation
    "! Generates the next sequential Business Partner code by searching the maximum existing value in active and draft tables.
    "! @parameter rv_bp_code | Generated formatted Business Partner code string
    CLASS-METHODS get_next_bp_code
      RETURNING
        VALUE(rv_bp_code) TYPE zmerp_bus_part-partner_code
      RAISING
        cx_number_ranges.

    "! Generates the next sequential Item code by searching the maximum existing value in active and draft tables.
    "! @parameter rv_item_code | Generated formatted Item code string
    CLASS-METHODS get_next_item_code
      RETURNING
        VALUE(rv_item_code) TYPE zmerp_item-item_code
      RAISING
        cx_number_ranges.

    "! Generates the next sequential Item Group code by searching the maximum existing value in active and draft tables.
    "! @parameter rv_item_grp_code | Generated formatted Item Group code string
    CLASS-METHODS get_next_item_grp_code
      RETURNING
        VALUE(rv_item_grp_code) TYPE zmerp_item_group-item_group_code
      RAISING
        cx_number_ranges.

    "! Generates the next sequential VAT code by searching the maximum existing value in active and draft tables.
    "! @parameter rv_vat_code | Generated formatted VAT code string
    CLASS-METHODS get_next_vat_code
      RETURNING
        VALUE(rv_vat_code) TYPE zmerp_vat_rate-vat_code
      RAISING
        cx_number_ranges.

    "! Generates the next sequential Warehouse code by searching the maximum existing value in active and draft tables.
    "! @parameter rv_wh_id | Generated formatted Warehouse ID string
    CLASS-METHODS get_next_warehouse_code
      RETURNING
        VALUE(rv_wh_id) TYPE zmerp_warehouse-warehouse_code
      RAISING
        cx_number_ranges.

    "! Generates the next sequential Purchase Order number by searching maximum existing value for specified company code.
    "! @parameter iv_company_code | Company code context
    "! @parameter rv_po_num       | Generated formatted Purchase Order number string
    CLASS-METHODS get_next_po_number
      IMPORTING
        iv_company_code  TYPE zmerp_company_code
      RETURNING
        VALUE(rv_po_num) TYPE zmerp_po_hdr-document_number
      RAISING
        cx_number_ranges.

    " Standard NRO Generation
    "! Generates the next sequential Business Partner code using standard SAP Number Range Runtime API.
    "! @parameter rv_bp_code | Generated formatted Business Partner code string from NRO
    CLASS-METHODS get_next_bp_code_nro
      RETURNING
        VALUE(rv_bp_code) TYPE zmerp_bus_part-partner_code
      RAISING
        cx_number_ranges.

    "! Generates the next sequential Item code using standard SAP Number Range Runtime API.
    "! @parameter rv_item_code | Generated formatted Item code string from NRO
    CLASS-METHODS get_next_item_code_nro
      RETURNING
        VALUE(rv_item_code) TYPE zmerp_item-item_code
      RAISING
        cx_number_ranges.

    "! Generates the next sequential Item Group code using standard SAP Number Range Runtime API.
    "! @parameter rv_item_grp_code | Generated formatted Item Group code string from NRO
    CLASS-METHODS get_next_item_grp_code_nro
      RETURNING
        VALUE(rv_item_grp_code) TYPE zmerp_item_group-item_group_code
      RAISING
        cx_number_ranges.

    "! Generates the next sequential VAT code using standard SAP Number Range Runtime API.
    "! @parameter rv_vat_code | Generated formatted VAT code string from NRO
    CLASS-METHODS get_next_vat_code_nro
      RETURNING
        VALUE(rv_vat_code) TYPE zmerp_vat_rate-vat_code
      RAISING
        cx_number_ranges.

    "! Generates the next sequential Warehouse code using standard SAP Number Range Runtime API.
    "! @parameter rv_wh_id | Generated formatted Warehouse ID string from NRO
    CLASS-METHODS get_next_warehouse_code_nro
      RETURNING
        VALUE(rv_wh_id) TYPE zmerp_warehouse-warehouse_code
      RAISING
        cx_number_ranges.

    "! Generates the next sequential Purchase Order number using NRO API with company subobject.
    "! @parameter iv_company_code | Company code context
    "! @parameter rv_po_num       | Generated formatted Purchase Order number string
    CLASS-METHODS get_next_po_number_nro
      IMPORTING
        iv_company_code  TYPE zmerp_company_code
      RETURNING
        VALUE(rv_po_num) TYPE zmerp_po_hdr-document_number
      RAISING
        cx_number_ranges.

    " Bulk NRO Generation Methods
    "! Generates multiple sequential Business Partner codes using NRO API with DB fallback.
    "! @parameter iv_count | Total count of sequential codes requested
    "! @parameter rt_codes | Table of generated formatted Business Partner codes
    CLASS-METHODS get_next_bp_codes_nro
      IMPORTING
        iv_count        TYPE i
      RETURNING
        VALUE(rt_codes) TYPE string_table
      RAISING
        cx_number_ranges.

    "! Generates multiple sequential Item codes using NRO API with DB fallback.
    "! @parameter iv_count | Total count of sequential codes requested
    "! @parameter rt_codes | Table of generated formatted Item codes
    CLASS-METHODS get_next_item_codes_nro
      IMPORTING
        iv_count        TYPE i
      RETURNING
        VALUE(rt_codes) TYPE string_table
      RAISING
        cx_number_ranges.

    "! Generates multiple sequential Item Group codes using NRO API with DB fallback.
    "! @parameter iv_count | Total count of sequential codes requested
    "! @parameter rt_codes | Table of generated formatted Item Group codes
    CLASS-METHODS get_next_item_grp_codes_nro
      IMPORTING
        iv_count        TYPE i
      RETURNING
        VALUE(rt_codes) TYPE string_table
      RAISING
        cx_number_ranges.

    "! Generates multiple sequential VAT codes using NRO API with DB fallback.
    "! @parameter iv_count | Total count of sequential codes requested
    "! @parameter rt_codes | Table of generated formatted VAT codes
    CLASS-METHODS get_next_vat_codes_nro
      IMPORTING
        iv_count        TYPE i
      RETURNING
        VALUE(rt_codes) TYPE string_table
      RAISING
        cx_number_ranges.

    "! Generates multiple sequential Warehouse codes using NRO API with DB fallback.
    "! @parameter iv_count | Total count of sequential codes requested
    "! @parameter rt_codes | Table of generated formatted Warehouse codes
    CLASS-METHODS get_next_wh_codes_nro
      IMPORTING
        iv_count        TYPE i
      RETURNING
        VALUE(rt_codes) TYPE string_table
      RAISING
        cx_number_ranges.

    "! Generates multiple sequential Purchase Order numbers using NRO API with DB fallback.
    "! @parameter iv_company_code | Company code context
    "! @parameter iv_count        | Total count of sequential codes requested
    "! @parameter rt_codes        | Table of generated formatted Purchase Order numbers
    CLASS-METHODS get_next_po_codes_nro
      IMPORTING
        iv_company_code TYPE zmerp_company_code
        iv_count        TYPE i
      RETURNING
        VALUE(rt_codes) TYPE string_table
      RAISING
        cx_number_ranges.

    " NRO Setup & Administration
    "! Synchronizes current NRO interval levels for Master Data with actual active database record counts.
    CLASS-METHODS sync_intervals_from_db.

    "! Synchronizes current NRO interval levels for all Master Data objects with actual active database record counts.
    CLASS-METHODS sync_master_intervals_from_db.

    "! Synchronizes current NRO interval levels for all Transactional Documents across active companies.
    CLASS-METHODS sync_doc_intervals_from_db.

    "! Synchronizes Business Partner NRO interval level with actual active database record count.
    CLASS-METHODS sync_bp_interval_from_db.

    "! Synchronizes Item NRO interval level with actual active database record count.
    CLASS-METHODS sync_item_interval_from_db.

    "! Synchronizes Item Group NRO interval level with actual active database record count.
    CLASS-METHODS sync_item_grp_interval_from_db.

    "! Synchronizes VAT NRO interval level with actual active database record count.
    CLASS-METHODS sync_vat_interval_from_db.

    "! Synchronizes Warehouse NRO interval level with actual active database record count.
    CLASS-METHODS sync_whse_interval_from_db.

    "! Synchronizes Purchase Order NRO interval level for specified company code.
    "! @parameter iv_company_code | Company code context
    CLASS-METHODS sync_po_interval_from_db
      IMPORTING
        iv_company_code TYPE zmerp_company_code.

  PRIVATE SECTION.

    " Internal Helpers
    "! Generic sequential number generator based on entity metadata and company context.
    CLASS-METHODS get_next_number
      IMPORTING
        is_meta            TYPE zif_merp_constants=>ty_entity_metadata
        iv_company_code    TYPE zmerp_company_code OPTIONAL
        iv_prefix_override TYPE string OPTIONAL
      RETURNING
        VALUE(rv_number)   TYPE string
      RAISING
        cx_number_ranges.

    "! Queries highest current key from specified database table matching prefix pattern and optional company code.
    CLASS-METHODS get_max_code_from_db
      IMPORTING
        iv_table        TYPE string
        iv_field        TYPE string
        iv_prefix       TYPE string
        iv_company_code TYPE zmerp_company_code OPTIONAL
      RETURNING
        VALUE(rv_code)  TYPE string.

    "! Extracts and converts numeric suffix from string key after prefix offset.
    CLASS-METHODS extract_numeric_suffix
      IMPORTING
        iv_code           TYPE string
        iv_offset         TYPE i
      RETURNING
        VALUE(rv_numeric) TYPE int8.

    "! Generic bulk sequential number generator based on entity metadata.
    CLASS-METHODS get_next_numbers
      IMPORTING
        is_meta            TYPE zif_merp_constants=>ty_entity_metadata
        iv_count           TYPE i
        iv_company_code    TYPE zmerp_company_code OPTIONAL
        iv_prefix_override TYPE string OPTIONAL
      RETURNING
        VALUE(rt_codes)    TYPE string_table
      RAISING
        cx_number_ranges.
    "! Reads maximum numeric suffix from database for specific entity metadata.
    CLASS-METHODS get_max_level_from_db
      IMPORTING
        is_meta            TYPE zif_merp_constants=>ty_entity_metadata
        iv_company_code    TYPE zmerp_company_code OPTIONAL
        iv_prefix_override TYPE string OPTIONAL
      RETURNING
        VALUE(rv_level)    TYPE int8.
ENDCLASS.

CLASS zcl_merp_num_range_util IMPLEMENTATION.

  METHOD get_next_bp_code.
    rv_bp_code = get_next_number( zif_merp_constants=>c_bp ).
  ENDMETHOD.


  METHOD get_next_item_code.
    rv_item_code = get_next_number( zif_merp_constants=>c_item ).
  ENDMETHOD.


  METHOD get_next_item_grp_code.
    rv_item_grp_code = get_next_number( zif_merp_constants=>c_ig ).
  ENDMETHOD.


  METHOD get_next_vat_code.
    rv_vat_code = get_next_number( zif_merp_constants=>c_vat ).
  ENDMETHOD.


  METHOD get_next_warehouse_code.
    rv_wh_id = get_next_number( zif_merp_constants=>c_wh ).
  ENDMETHOD.


  METHOD get_next_po_number.
    TRY.
        DATA(ls_company) = NEW zcl_merp_md_comp_code_sel( )->zif_merp_md_comp_code_sel~read_company( iv_company_code ).
        DATA(lv_prefix)  = ls_company-CompanyPrefix.
      CATCH zcx_merp_md.
        CLEAR lv_prefix.
    ENDTRY.

    rv_po_num = get_next_number(
      is_meta            = zif_merp_constants=>c_po
      iv_company_code    = iv_company_code
      iv_prefix_override = CONV #( lv_prefix ) ).
  ENDMETHOD.


  METHOD get_next_bp_code_nro.
    rv_bp_code = zcl_merp_nro_admin_util=>get_next_number_from_nro( zif_merp_constants=>c_bp ).

    IF rv_bp_code IS INITIAL.
      rv_bp_code = get_next_bp_code( ).
    ENDIF.
  ENDMETHOD.


  METHOD get_next_item_code_nro.
    rv_item_code = zcl_merp_nro_admin_util=>get_next_number_from_nro( zif_merp_constants=>c_item ).

    IF rv_item_code IS INITIAL.
      rv_item_code = get_next_item_code( ).
    ENDIF.
  ENDMETHOD.


  METHOD get_next_item_grp_code_nro.
    rv_item_grp_code = zcl_merp_nro_admin_util=>get_next_number_from_nro( zif_merp_constants=>c_ig ).

    IF rv_item_grp_code IS INITIAL.
      rv_item_grp_code = get_next_item_grp_code( ).
    ENDIF.
  ENDMETHOD.


  METHOD get_next_vat_code_nro.
    rv_vat_code = zcl_merp_nro_admin_util=>get_next_number_from_nro( zif_merp_constants=>c_vat ).

    IF rv_vat_code IS INITIAL.
      rv_vat_code = get_next_vat_code( ).
    ENDIF.
  ENDMETHOD.


  METHOD get_next_warehouse_code_nro.
    rv_wh_id = zcl_merp_nro_admin_util=>get_next_number_from_nro( zif_merp_constants=>c_wh ).

    IF rv_wh_id IS INITIAL.
      rv_wh_id = get_next_warehouse_code( ).
    ENDIF.
  ENDMETHOD.


  METHOD get_next_po_number_nro.
    TRY.
        DATA(ls_company) = NEW zcl_merp_md_comp_code_sel( )->zif_merp_md_comp_code_sel~read_company( iv_company_code ).
        DATA(lv_prefix)  = ls_company-CompanyPrefix.
      CATCH zcx_merp_md.
        CLEAR lv_prefix.
    ENDTRY.

    rv_po_num = zcl_merp_nro_admin_util=>get_next_number_from_nro(
      is_meta            = zif_merp_constants=>c_po
      iv_company_code    = iv_company_code
      iv_prefix_override = CONV #( lv_prefix ) ).

    IF rv_po_num IS INITIAL.
      rv_po_num = get_next_po_number( iv_company_code ).
    ENDIF.
  ENDMETHOD.

    METHOD get_next_bp_codes_nro.
    rt_codes = zcl_merp_nro_admin_util=>get_next_numbers_from_nro(
      is_meta  = zif_merp_constants=>c_bp
      iv_count = iv_count ).

    IF lines( rt_codes ) < iv_count.
      rt_codes = get_next_numbers(
        is_meta  = zif_merp_constants=>c_bp
        iv_count = iv_count ).
    ENDIF.
  ENDMETHOD.


  METHOD get_next_item_codes_nro.
    rt_codes = zcl_merp_nro_admin_util=>get_next_numbers_from_nro(
      is_meta  = zif_merp_constants=>c_item
      iv_count = iv_count ).

    IF lines( rt_codes ) < iv_count.
      rt_codes = get_next_numbers(
        is_meta  = zif_merp_constants=>c_item
        iv_count = iv_count ).
    ENDIF.
  ENDMETHOD.


  METHOD get_next_item_grp_codes_nro.
    rt_codes = zcl_merp_nro_admin_util=>get_next_numbers_from_nro(
      is_meta  = zif_merp_constants=>c_ig
      iv_count = iv_count ).

    IF lines( rt_codes ) < iv_count.
      rt_codes = get_next_numbers(
        is_meta  = zif_merp_constants=>c_ig
        iv_count = iv_count ).
    ENDIF.
  ENDMETHOD.


  METHOD get_next_vat_codes_nro.
    rt_codes = zcl_merp_nro_admin_util=>get_next_numbers_from_nro(
      is_meta  = zif_merp_constants=>c_vat
      iv_count = iv_count ).

    IF lines( rt_codes ) < iv_count.
      rt_codes = get_next_numbers(
        is_meta  = zif_merp_constants=>c_vat
        iv_count = iv_count ).
    ENDIF.
  ENDMETHOD.


  METHOD get_next_wh_codes_nro.
    rt_codes = zcl_merp_nro_admin_util=>get_next_numbers_from_nro(
      is_meta  = zif_merp_constants=>c_wh
      iv_count = iv_count ).

    IF lines( rt_codes ) < iv_count.
      rt_codes = get_next_numbers(
        is_meta  = zif_merp_constants=>c_wh
        iv_count = iv_count ).
    ENDIF.
  ENDMETHOD.


  METHOD get_next_po_codes_nro.
    TRY.
        DATA(ls_company) = NEW zcl_merp_md_comp_code_sel( )->zif_merp_md_comp_code_sel~read_company( iv_company_code ).
        DATA(lv_prefix)  = ls_company-CompanyPrefix.
      CATCH zcx_merp_md.
        CLEAR lv_prefix.
    ENDTRY.

    rt_codes = zcl_merp_nro_admin_util=>get_next_numbers_from_nro(
      is_meta            = zif_merp_constants=>c_po
      iv_count           = iv_count
      iv_company_code    = iv_company_code
      iv_prefix_override = CONV #( lv_prefix ) ).

    IF lines( rt_codes ) < iv_count.
      rt_codes = get_next_numbers(
        is_meta            = zif_merp_constants=>c_po
        iv_count           = iv_count
        iv_company_code    = iv_company_code
        iv_prefix_override = CONV #( lv_prefix ) ).
    ENDIF.
  ENDMETHOD.

  METHOD sync_intervals_from_db.
    sync_master_intervals_from_db( ).
    sync_doc_intervals_from_db( ).
  ENDMETHOD.


  METHOD sync_master_intervals_from_db.
    sync_bp_interval_from_db( ).
    sync_item_interval_from_db( ).
    sync_item_grp_interval_from_db( ).
    sync_vat_interval_from_db( ).
    sync_whse_interval_from_db( ).
  ENDMETHOD.


  METHOD sync_doc_intervals_from_db.

    SELECT company_code
      FROM zmerp_comp_code
      WHERE is_blocked = @abap_false
      INTO TABLE @DATA(lt_companies).

    LOOP AT lt_companies ASSIGNING FIELD-SYMBOL(<ls_company>).
      sync_po_interval_from_db( iv_company_code = <ls_company>-company_code ).
    ENDLOOP.
  ENDMETHOD.


  METHOD sync_bp_interval_from_db.
    zcl_merp_nro_admin_util=>save_interval(
      iv_object = zif_merp_constants=>c_bp-number_object
      iv_level  = get_max_level_from_db( zif_merp_constants=>c_bp ) ).
  ENDMETHOD.


  METHOD sync_item_interval_from_db.
    zcl_merp_nro_admin_util=>save_interval(
      iv_object = zif_merp_constants=>c_item-number_object
      iv_level  = get_max_level_from_db( zif_merp_constants=>c_item ) ).
  ENDMETHOD.


  METHOD sync_item_grp_interval_from_db.
    zcl_merp_nro_admin_util=>save_interval(
      iv_object = zif_merp_constants=>c_ig-number_object
      iv_level  = get_max_level_from_db( zif_merp_constants=>c_ig ) ).
  ENDMETHOD.


  METHOD sync_vat_interval_from_db.
    zcl_merp_nro_admin_util=>save_interval(
      iv_object = zif_merp_constants=>c_vat-number_object
      iv_level  = get_max_level_from_db( zif_merp_constants=>c_vat ) ).
  ENDMETHOD.


  METHOD sync_whse_interval_from_db.
    zcl_merp_nro_admin_util=>save_interval(
      iv_object = zif_merp_constants=>c_wh-number_object
      iv_level  = get_max_level_from_db( zif_merp_constants=>c_wh ) ).
  ENDMETHOD.


  METHOD sync_po_interval_from_db.
    TRY.
        DATA(ls_company) = NEW zcl_merp_md_comp_code_sel( )->zif_merp_md_comp_code_sel~read_company( iv_company_code ).
        DATA(lv_prefix)  = ls_company-CompanyPrefix.
      CATCH zcx_merp_md.
        CLEAR lv_prefix.
    ENDTRY.

    zcl_merp_nro_admin_util=>save_interval(
      iv_object    = zif_merp_constants=>c_po-number_object
      iv_subobject = CONV #( iv_company_code )
      iv_level     = get_max_level_from_db(
                      is_meta            = zif_merp_constants=>c_po
                      iv_company_code    = iv_company_code
                      iv_prefix_override = CONV #( lv_prefix ) ) ).
  ENDMETHOD.

  METHOD get_next_number.
    DATA(lv_prefix) = COND string(
      WHEN iv_prefix_override IS SUPPLIED AND iv_prefix_override IS NOT INITIAL
      THEN iv_prefix_override
      ELSE is_meta-prefix ).

    DATA(lv_prefix_length) = strlen( lv_prefix ).

    " Active table search is always performed
    DATA(lv_max_active) = get_max_code_from_db(
      iv_table        = is_meta-table_db
      iv_field        = is_meta-field_db
      iv_prefix       = lv_prefix
      iv_company_code = iv_company_code ).

    " Skip draft table search for transactional documents since late numbering leaves draft document numbers initial
    DATA(lv_max_draft) = COND string(
      WHEN is_meta-table_draft IS NOT INITIAL
       AND is_meta-field_draft IS NOT INITIAL
       AND is_meta-field_db    <> 'document_number'
      THEN get_max_code_from_db(
             iv_table        = is_meta-table_draft
             iv_field        = is_meta-field_draft
             iv_prefix       = lv_prefix
             iv_company_code = iv_company_code ) ).

    DATA(lv_max_numeric) = nmax(
      val1 = extract_numeric_suffix(
               iv_code   = lv_max_active
               iv_offset = lv_prefix_length )
      val2 = extract_numeric_suffix(
               iv_code   = lv_max_draft
               iv_offset = lv_prefix_length ) ).

    lv_max_numeric += 1.

    rv_number = zcl_merp_format_util=>format_code(
      iv_prefix       = lv_prefix
      iv_number       = lv_max_numeric
      iv_total_length = is_meta-length ).

    IF rv_number IS INITIAL.
      RAISE EXCEPTION NEW cx_number_ranges( ).
    ENDIF.
  ENDMETHOD.


  METHOD get_max_code_from_db.
    DATA: BEGIN OF ls_result,
            val TYPE string,
          END OF ls_result.

    DATA(lv_prefix_upper) = to_upper( iv_prefix ).
    DATA(lv_prefix_lower) = to_lower( iv_prefix ).

    DATA(lv_comp_field) = COND string(
      WHEN to_lower( iv_table ) CS '_d' THEN 'companycode'
      ELSE 'company_code' ).

    DATA(lv_company_filter) = COND string(
      WHEN iv_company_code IS NOT INITIAL
      THEN | AND { lv_comp_field } = '{ iv_company_code }'|
      ELSE '' ).

    TRY.
        DATA(lv_where) = |( { iv_field } LIKE '{ lv_prefix_upper }%' OR { iv_field } LIKE '{ lv_prefix_lower }%' ){ lv_company_filter }|.
        DATA(lv_order) = |{ iv_field } DESCENDING|.

        SELECT (iv_field)
          FROM (iv_table)
          WHERE (lv_where)
          ORDER BY (lv_order)
          INTO @ls_result
          UP TO 1 ROWS.
        ENDSELECT.

        rv_code = ls_result-val.

      CATCH cx_sy_dynamic_osql_error cx_sy_open_sql_db cx_root.
        CLEAR rv_code.
    ENDTRY.
  ENDMETHOD.


  METHOD extract_numeric_suffix.

    IF iv_code IS INITIAL OR strlen( iv_code ) <= iv_offset.
      RETURN.
    ENDIF.
    TRY.
        DATA(lv_num_part) = substring(
        val = iv_code
        off = iv_offset ).
        IF lv_num_part CO '0123456789'.
          rv_numeric = CONV int8( lv_num_part ).
        ENDIF.
      CATCH cx_sy_strg_par_val cx_sy_conversion_error cx_sy_arithmetic_overflow.
        CLEAR rv_numeric.
    ENDTRY.
  ENDMETHOD.

  METHOD get_next_numbers.
    IF iv_count <= 0.
      RETURN.
    ENDIF.

    DATA(lv_prefix) = COND string(
      WHEN iv_prefix_override IS SUPPLIED AND iv_prefix_override IS NOT INITIAL
      THEN iv_prefix_override
      ELSE is_meta-prefix ).

    DATA(lv_prefix_length) = strlen( lv_prefix ).

    DATA(lv_max_active) = get_max_code_from_db(
      iv_table        = is_meta-table_db
      iv_field        = is_meta-field_db
      iv_prefix       = lv_prefix
      iv_company_code = iv_company_code ).

    DATA(lv_max_draft) = COND string(
      WHEN is_meta-table_draft IS NOT INITIAL
       AND is_meta-field_draft IS NOT INITIAL
       AND is_meta-field_db    <> 'document_number'
      THEN get_max_code_from_db(
             iv_table        = is_meta-table_draft
             iv_field        = is_meta-field_draft
             iv_prefix       = lv_prefix
             iv_company_code = iv_company_code ) ).

    DATA(lv_max_numeric) = nmax(
      val1 = extract_numeric_suffix(
               iv_code   = lv_max_active
               iv_offset = lv_prefix_length )
      val2 = extract_numeric_suffix(
               iv_code   = lv_max_draft
               iv_offset = lv_prefix_length ) ).

    DO iv_count TIMES.
      lv_max_numeric += 1.
      DATA(lv_code) = zcl_merp_format_util=>format_code(
        iv_prefix       = lv_prefix
        iv_number       = lv_max_numeric
        iv_total_length = is_meta-length ).

      IF lv_code IS INITIAL.
        CLEAR rt_codes.
        RAISE EXCEPTION NEW cx_number_ranges( ).
      ENDIF.

      APPEND lv_code TO rt_codes.
    ENDDO.
  ENDMETHOD.

  METHOD get_max_level_from_db.
    DATA(lv_prefix) = COND string(
      WHEN iv_prefix_override IS SUPPLIED AND iv_prefix_override IS NOT INITIAL
      THEN iv_prefix_override
      ELSE is_meta-prefix ).

    DATA(lv_max_code) = get_max_code_from_db(
      iv_table        = is_meta-table_db
      iv_field        = is_meta-field_db
      iv_prefix       = lv_prefix
      iv_company_code = iv_company_code ).

    rv_level = extract_numeric_suffix(
      iv_code   = lv_max_code
      iv_offset = strlen( lv_prefix ) ).
  ENDMETHOD.

ENDCLASS.
