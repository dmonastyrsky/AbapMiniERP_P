CLASS zcl_merp_num_range_util DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

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
    "! @parameter iv_count        | Total count of sequential numbers requested
    "! @parameter rt_numbers      | Table of generated formatted Purchase Order numbers
    CLASS-METHODS get_next_po_numbers_nro
      IMPORTING
        iv_company_code TYPE zmerp_company_code
        iv_count        TYPE i
      RETURNING
        VALUE(rt_numbers) TYPE string_table
      RAISING
        cx_number_ranges.

    "! Generates multiple sequential Goods Receipt numbers using NRO API with DB fallback.
    "! @parameter iv_company_code | Company code context
    "! @parameter iv_count        | Total count of sequential numbers requested
    "! @parameter rt_numbers      | Table of generated formatted Goods Receipt numbers
    CLASS-METHODS get_next_gr_numbers_nro
      IMPORTING
        iv_company_code TYPE zmerp_company_code
        iv_count        TYPE i
      RETURNING
        VALUE(rt_numbers) TYPE string_table
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

    "! Synchronizes Goods Receipt NRO interval level for specified company code.
    "! @parameter iv_company_code | Company code context
    CLASS-METHODS sync_gr_interval_from_db
      IMPORTING
        iv_company_code TYPE zmerp_company_code.

  PRIVATE SECTION.

    " Internal Helpers
    "! Prefix of the document numbers of a company code (initial if the company code is unknown).
    CLASS-METHODS get_company_prefix
      IMPORTING
        iv_company_code  TYPE zmerp_company_code
      RETURNING
        VALUE(rv_prefix) TYPE string.

    "! Several master data codes: NRO with fallback to the database max search.
    CLASS-METHODS get_next_codes_nro
      IMPORTING
        is_meta         TYPE zif_merp_constants=>ty_entity_metadata
        iv_count        TYPE i
      RETURNING
        VALUE(rt_codes) TYPE string_table
      RAISING
        cx_number_ranges.

    "! Several document numbers of a company code: NRO with fallback to the database max search.
    CLASS-METHODS get_next_doc_numbers_nro
      IMPORTING
        is_meta           TYPE zif_merp_constants=>ty_entity_metadata
        iv_company_code   TYPE zmerp_company_code
        iv_count          TYPE i
      RETURNING
        VALUE(rt_numbers) TYPE string_table
      RAISING
        cx_number_ranges.

    "! Synchronizes the NRO interval of an entity (optionally of a company code subobject) with the database.
    "! The interval is NOT changed if the maximum cannot be read (a wrong level would lead to duplicate numbers).
    CLASS-METHODS sync_interval
      IMPORTING
        is_meta         TYPE zif_merp_constants=>ty_entity_metadata
        iv_company_code TYPE zmerp_company_code OPTIONAL.

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

    "! Highest numeric suffix used in the active (and, for master data, draft) table.
    CLASS-METHODS get_max_numeric
      IMPORTING
        is_meta         TYPE zif_merp_constants=>ty_entity_metadata
        iv_prefix       TYPE string
        iv_company_code TYPE zmerp_company_code OPTIONAL
      RETURNING
        VALUE(rv_max)   TYPE int8
      RAISING
        cx_number_ranges.

    "! Queries highest current key from specified database table matching prefix pattern and optional company code.
    "! @raising cx_number_ranges | The database could not be read: the caller must not continue with a guessed value
    CLASS-METHODS get_max_code_from_db
      IMPORTING
        iv_table        TYPE string
        iv_field        TYPE string
        iv_prefix       TYPE string
        iv_company_code TYPE zmerp_company_code OPTIONAL
      RETURNING
        VALUE(rv_code)  TYPE string
      RAISING
        cx_number_ranges.

    "! Extracts and converts numeric suffix from string key after prefix offset.
    CLASS-METHODS extract_numeric_suffix
      IMPORTING
        iv_code           TYPE string
        iv_offset         TYPE i
      RETURNING
        VALUE(rv_numeric) TYPE int8.

    "! Reads maximum numeric suffix from database for specific entity metadata.
    CLASS-METHODS get_max_level_from_db
      IMPORTING
        is_meta            TYPE zif_merp_constants=>ty_entity_metadata
        iv_company_code    TYPE zmerp_company_code OPTIONAL
        iv_prefix_override TYPE string OPTIONAL
      RETURNING
        VALUE(rv_level)    TYPE int8
      RAISING
        cx_number_ranges.
ENDCLASS.

CLASS zcl_merp_num_range_util IMPLEMENTATION.

  METHOD get_next_bp_codes_nro.
    rt_codes = get_next_codes_nro( is_meta = zif_merp_constants=>c_bp iv_count = iv_count ).
  ENDMETHOD.

  METHOD get_next_item_codes_nro.
    rt_codes = get_next_codes_nro( is_meta = zif_merp_constants=>c_item iv_count = iv_count ).
  ENDMETHOD.

  METHOD get_next_item_grp_codes_nro.
    rt_codes = get_next_codes_nro( is_meta = zif_merp_constants=>c_ig iv_count = iv_count ).
  ENDMETHOD.

  METHOD get_next_vat_codes_nro.
    rt_codes = get_next_codes_nro( is_meta = zif_merp_constants=>c_vat iv_count = iv_count ).
  ENDMETHOD.

  METHOD get_next_wh_codes_nro.
    rt_codes = get_next_codes_nro( is_meta = zif_merp_constants=>c_wh iv_count = iv_count ).
  ENDMETHOD.

  METHOD get_next_po_numbers_nro.
    rt_numbers = get_next_doc_numbers_nro( is_meta         = zif_merp_constants=>c_po
                                           iv_company_code = iv_company_code
                                           iv_count        = iv_count ).
  ENDMETHOD.

  METHOD get_next_gr_numbers_nro.
    rt_numbers = get_next_doc_numbers_nro( is_meta         = zif_merp_constants=>c_gr
                                           iv_company_code = iv_company_code
                                           iv_count        = iv_count ).
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
    " All companies, also blocked ones: their documents still exist and keep their numbering
    SELECT company_code
      FROM zmerp_comp_code
      INTO TABLE @DATA(lt_companies).

    LOOP AT lt_companies ASSIGNING FIELD-SYMBOL(<ls_company>).
      sync_po_interval_from_db( iv_company_code = <ls_company>-company_code ).
      sync_gr_interval_from_db( iv_company_code = <ls_company>-company_code ).
    ENDLOOP.
  ENDMETHOD.

  METHOD sync_bp_interval_from_db.
    sync_interval( zif_merp_constants=>c_bp ).
  ENDMETHOD.

  METHOD sync_item_interval_from_db.
    sync_interval( zif_merp_constants=>c_item ).
  ENDMETHOD.

  METHOD sync_item_grp_interval_from_db.
    sync_interval( zif_merp_constants=>c_ig ).
  ENDMETHOD.

  METHOD sync_vat_interval_from_db.
    sync_interval( zif_merp_constants=>c_vat ).
  ENDMETHOD.

  METHOD sync_whse_interval_from_db.
    sync_interval( zif_merp_constants=>c_wh ).
  ENDMETHOD.

  METHOD sync_po_interval_from_db.
    sync_interval( is_meta         = zif_merp_constants=>c_po
                   iv_company_code = iv_company_code ).
  ENDMETHOD.

  METHOD sync_gr_interval_from_db.
    sync_interval( is_meta         = zif_merp_constants=>c_gr
                   iv_company_code = iv_company_code ).
  ENDMETHOD.

  METHOD get_company_prefix.
    TRY.
        rv_prefix = NEW zcl_merp_md_comp_code_sel( )->zif_merp_md_comp_code_sel~read_company( iv_company_code )-CompanyPrefix.
      CATCH zcx_merp_md.
        CLEAR rv_prefix.
    ENDTRY.
  ENDMETHOD.

  METHOD get_next_codes_nro.
    rt_codes = zcl_merp_nro_admin_util=>get_next_numbers_from_nro(
      is_meta  = is_meta
      iv_count = iv_count ).

    IF lines( rt_codes ) < iv_count.
      rt_codes = get_next_numbers(
        is_meta  = is_meta
        iv_count = iv_count ).
    ENDIF.
  ENDMETHOD.

  METHOD get_next_doc_numbers_nro.
    DATA(lv_prefix) = get_company_prefix( iv_company_code ).

    rt_numbers = zcl_merp_nro_admin_util=>get_next_numbers_from_nro(
      is_meta            = is_meta
      iv_count           = iv_count
      iv_company_code    = iv_company_code
      iv_prefix_override = lv_prefix ).

    IF lines( rt_numbers ) < iv_count.
      rt_numbers = get_next_numbers(
        is_meta            = is_meta
        iv_count           = iv_count
        iv_company_code    = iv_company_code
        iv_prefix_override = lv_prefix ).
    ENDIF.
  ENDMETHOD.

  METHOD sync_interval.
    TRY.
        IF iv_company_code IS INITIAL.
          DATA(lv_level) = get_max_level_from_db( is_meta ).

          zcl_merp_nro_admin_util=>save_interval(
            iv_object = is_meta-number_object
            iv_level  = lv_level ).
        ELSE.
          DATA(lv_company_level) = get_max_level_from_db(
            is_meta            = is_meta
            iv_company_code    = iv_company_code
            iv_prefix_override = get_company_prefix( iv_company_code ) ).

          zcl_merp_nro_admin_util=>save_interval(
            iv_object    = is_meta-number_object
            iv_subobject = CONV #( iv_company_code )
            iv_level     = lv_company_level ).
        ENDIF.

      CATCH cx_number_ranges.
        " The maximum could not be read: keep the current interval instead of saving a wrong (too low) level
        RETURN.
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

    DATA(lv_max_numeric) = get_max_numeric(
      is_meta         = is_meta
      iv_prefix       = lv_prefix
      iv_company_code = iv_company_code ).

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

  METHOD get_max_numeric.
    DATA(lv_prefix_length) = strlen( iv_prefix ).

    " Active table search is always performed
    DATA(lv_max_active) = get_max_code_from_db(
      iv_table        = is_meta-table_db
      iv_field        = is_meta-field_db
      iv_prefix       = iv_prefix
      iv_company_code = iv_company_code ).

    " Skip draft table search for transactional documents since late numbering leaves draft document numbers initial
    " (metadata field names are upper case, so the comparison is done in upper case)
    DATA(lv_max_draft) = COND string(
      WHEN is_meta-table_draft IS NOT INITIAL
       AND is_meta-field_draft IS NOT INITIAL
       AND to_upper( is_meta-field_db ) <> 'DOCUMENT_NUMBER'
      THEN get_max_code_from_db(
             iv_table        = is_meta-table_draft
             iv_field        = is_meta-field_draft
             iv_prefix       = iv_prefix
             iv_company_code = iv_company_code ) ).

    rv_max = nmax(
      val1 = extract_numeric_suffix(
               iv_code   = lv_max_active
               iv_offset = lv_prefix_length )
      val2 = extract_numeric_suffix(
               iv_code   = lv_max_draft
               iv_offset = lv_prefix_length ) ).
  ENDMETHOD.

  METHOD get_max_code_from_db.
    DATA: BEGIN OF ls_result,
            val TYPE string,
          END OF ls_result.
    DATA lx_db TYPE REF TO cx_root.

    " Values are escaped because they are part of a dynamic WHERE condition
    DATA(lv_prefix_upper) = cl_abap_dyn_prg=>escape_quotes( to_upper( iv_prefix ) ).
    DATA(lv_prefix_lower) = cl_abap_dyn_prg=>escape_quotes( to_lower( iv_prefix ) ).

    DATA(lv_comp_field) = COND string(
      WHEN to_lower( iv_table ) CS '_d' THEN 'companycode'
      ELSE 'company_code' ).

    DATA(lv_company_filter) = COND string(
      WHEN iv_company_code IS NOT INITIAL
      THEN | AND { lv_comp_field } = '{ cl_abap_dyn_prg=>escape_quotes( CONV string( iv_company_code ) ) }'|
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

      CATCH cx_sy_dynamic_osql_error cx_sy_open_sql_db INTO lx_db.
        " Do not return an empty maximum here: the numbering would restart from 1 and could issue a used number
        RAISE EXCEPTION NEW cx_number_ranges( previous = lx_db ).
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
