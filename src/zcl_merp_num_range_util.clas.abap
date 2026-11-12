CLASS zcl_merp_num_range_util DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! Document of the same type that needs a number (the company code is the number range subobject)
    TYPES: BEGIN OF ty_doc_number_request,
             HeaderUUID  TYPE sysuuid_x16,
             IsDraft     TYPE abp_behv_flag,
             CompanyCode TYPE zmerp_company_code,
           END OF ty_doc_number_request,
           tt_doc_number_requests TYPE STANDARD TABLE OF ty_doc_number_request WITH EMPTY KEY.

    "! Number drawn for a document
    TYPES: BEGIN OF ty_doc_number,
             HeaderUUID     TYPE sysuuid_x16,
             IsDraft        TYPE abp_behv_flag,
             DocumentNumber TYPE zmerp_doc_num,
           END OF ty_doc_number,
           tt_doc_numbers TYPE STANDARD TABLE OF ty_doc_number WITH EMPTY KEY.

    " Bulk NRO Generation Methods
    "! Draws master data codes via NRO in one bulk call (no fallback, N1): fewer codes than requested
    "! raise CX_NUMBER_RANGES, the caller fails its instances.
    "! @parameter is_meta  | NRO metadata of the master data object (zif_merp_constants=>c_bp, c_item, c_ig, c_vat, c_wh)
    "! @parameter iv_count | Number of codes
    "! @parameter rt_codes | Formatted codes in the order of drawing
    CLASS-METHODS get_md_codes
      IMPORTING
        is_meta         TYPE zif_merp_constants=>ty_entity_metadata
        iv_count        TYPE i
      RETURNING
        VALUE(rt_codes) TYPE string_table
      RAISING
        cx_number_ranges.

    "! Draws document numbers via NRO: one bulk call per company code, numbers in the order of the documents.
    "! Documents of a company whose numbers cannot be drawn get none (no fallback, N1): the caller's
    "! validation rejects them.
    "! @parameter is_meta      | NRO metadata of the document type (zif_merp_constants=>c_po, c_gr, c_so, c_gi)
    "! @parameter it_requests  | Documents without a number, with company code
    "! @parameter rt_numbers   | Drawn numbers (documents without a number are missing)
    CLASS-METHODS get_doc_numbers
      IMPORTING
        is_meta           TYPE zif_merp_constants=>ty_entity_metadata
        it_requests       TYPE tt_doc_number_requests
      RETURNING
        VALUE(rt_numbers) TYPE tt_doc_numbers.

    " NRO Setup & Administration
    "! Synchronizes the NRO interval levels of master data and documents with the database.
    CLASS-METHODS sync_intervals_from_db.

    "! Synchronizes the NRO interval levels of all master data objects with the database.
    CLASS-METHODS sync_master_intervals_from_db.

    "! Synchronizes the NRO interval levels of all document types of all company codes with the database.
    CLASS-METHODS sync_doc_intervals_from_db.

  PRIVATE SECTION.

    " Internal Helpers
    "! Prefix of the document numbers of a company code (initial if the company code is unknown).
    CLASS-METHODS get_company_prefix
      IMPORTING
        iv_company_code  TYPE zmerp_company_code
      RETURNING
        VALUE(rv_prefix) TYPE string.

    "! Several document numbers of a company code via NRO (no fallback, N1).
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

  METHOD get_md_codes.
    rt_codes = zcl_merp_nro_admin_util=>get_next_numbers_from_nro(
      is_meta  = is_meta
      iv_count = iv_count ).

    " No fallback to the database maximum: it would leave the NRO level behind and NRO would
    " issue the same code again later. Fewer codes than requested: the caller fails the instances
    IF lines( rt_codes ) < iv_count.
      CLEAR rt_codes.
      RAISE EXCEPTION NEW cx_number_ranges( ).
    ENDIF.
  ENDMETHOD.

  METHOD get_doc_numbers.
    DATA lt_numbers TYPE string_table.

    LOOP AT it_requests INTO DATA(ls_request)
         GROUP BY ls_request-CompanyCode
         INTO DATA(lv_company_code).

      DATA(lt_company_requests) = VALUE tt_doc_number_requests( FOR member IN GROUP lv_company_code ( member ) ).

      " An NRO error leaves the documents of this company without a number
      TRY.
          lt_numbers = get_next_doc_numbers_nro( is_meta         = is_meta
                                                 iv_company_code = lv_company_code
                                                 iv_count        = lines( lt_company_requests ) ).
        CATCH cx_number_ranges.
          CLEAR lt_numbers.
      ENDTRY.

      " Numbers in the order of the documents
      LOOP AT lt_company_requests INTO DATA(ls_company_request).
        DATA(lv_number) = VALUE string( lt_numbers[ sy-tabix ] OPTIONAL ).
        IF lv_number IS NOT INITIAL.
          APPEND VALUE #( HeaderUUID     = ls_company_request-HeaderUUID
                          IsDraft        = ls_company_request-IsDraft
                          DocumentNumber = CONV #( lv_number ) ) TO rt_numbers.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD sync_intervals_from_db.
    sync_master_intervals_from_db( ).
    sync_doc_intervals_from_db( ).
  ENDMETHOD.

  METHOD sync_master_intervals_from_db.
    TYPES tt_metas TYPE STANDARD TABLE OF zif_merp_constants=>ty_entity_metadata WITH EMPTY KEY.

    DATA(lt_metas) = VALUE tt_metas( ( zif_merp_constants=>c_bp )
                                     ( zif_merp_constants=>c_item )
                                     ( zif_merp_constants=>c_ig )
                                     ( zif_merp_constants=>c_vat )
                                     ( zif_merp_constants=>c_wh ) ).

    LOOP AT lt_metas INTO DATA(ls_meta).
      sync_interval( ls_meta ).
    ENDLOOP.
  ENDMETHOD.

  METHOD sync_doc_intervals_from_db.
    TYPES tt_metas TYPE STANDARD TABLE OF zif_merp_constants=>ty_entity_metadata WITH EMPTY KEY.

    DATA(lt_metas) = VALUE tt_metas( ( zif_merp_constants=>c_po )
                                     ( zif_merp_constants=>c_gr )
                                     ( zif_merp_constants=>c_so )
                                     ( zif_merp_constants=>c_gi ) ).

    " All companies, also blocked ones: their documents still exist and keep their numbering
    SELECT company_code
      FROM zmerp_comp_code
      INTO TABLE @DATA(lt_companies).

    LOOP AT lt_companies ASSIGNING FIELD-SYMBOL(<ls_company>).
      LOOP AT lt_metas INTO DATA(ls_meta).
        sync_interval( is_meta         = ls_meta
                       iv_company_code = <ls_company>-company_code ).
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_company_prefix.
    TRY.
        rv_prefix = NEW zcl_merp_md_comp_code_sel( )->zif_merp_md_comp_code_sel~read_company( iv_company_code )-CompanyPrefix.
      CATCH zcx_merp_md.
        CLEAR rv_prefix.
    ENDTRY.
  ENDMETHOD.

  METHOD get_next_doc_numbers_nro.
    rt_numbers = zcl_merp_nro_admin_util=>get_next_numbers_from_nro(
      is_meta            = is_meta
      iv_count           = iv_count
      iv_company_code    = iv_company_code
      iv_prefix_override = get_company_prefix( iv_company_code ) ).

    " No fallback to the database maximum (see get_md_codes): without numbers
    " validateDocumentNumber rejects the documents
    IF lines( rt_numbers ) < iv_count.
      CLEAR rt_numbers.
      RAISE EXCEPTION NEW cx_number_ranges( ).
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

  METHOD get_max_code_from_db.
    DATA: BEGIN OF ls_result,
            val TYPE string,
          END OF ls_result.
    DATA lx_db TYPE REF TO cx_root.

    " Values are escaped because they are part of a dynamic WHERE condition
    DATA(lv_prefix_upper) = cl_abap_dyn_prg=>escape_quotes( to_upper( iv_prefix ) ).
    DATA(lv_prefix_lower) = cl_abap_dyn_prg=>escape_quotes( to_lower( iv_prefix ) ).

    " Only active tables are read (C1): their company field is COMPANY_CODE
    DATA(lv_company_filter) = COND string(
      WHEN iv_company_code IS NOT INITIAL
      THEN | AND company_code = '{ cl_abap_dyn_prg=>escape_quotes( CONV string( iv_company_code ) ) }'|
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
