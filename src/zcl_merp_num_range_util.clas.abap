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
    "! @parameter rv_item_group_code | Generated formatted Item Group code string
    CLASS-METHODS get_next_item_group_code
      RETURNING
        VALUE(rv_item_group_code) TYPE zmerp_item_group-item_group_code
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
    "! @parameter rv_item_group_code | Generated formatted Item Group code string from NRO
    CLASS-METHODS get_next_item_group_code_nro
      RETURNING
        VALUE(rv_item_group_code) TYPE zmerp_item_group-item_group_code
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

    " Formatting Utilities
    "! Pads an input numeric value or string with leading zeros to specified total length.
    "! @parameter iv_value  | Input value to be padded
    "! @parameter iv_length | Target length of the output numeric string
    "! @parameter rv_code   | Zero-padded result string
    CLASS-METHODS add_leading_zeros
      IMPORTING
        iv_value       TYPE simple
        iv_length      TYPE i
      RETURNING
        VALUE(rv_code) TYPE string.

    "! Formats numeric sequence into target length string with prefix and optional zero padding.
    "! @parameter iv_number       | Numeric value to format
    "! @parameter iv_prefix       | Domain prefix string
    "! @parameter iv_total_length | Total desired length including prefix
    "! @parameter rv_code         | Formatted result string
    CLASS-METHODS format_code
      IMPORTING
        iv_number       TYPE simple
        iv_prefix       TYPE string
        iv_total_length TYPE i
      RETURNING
        VALUE(rv_code)  TYPE string.

    "! Convenience formatter for Business Partner code using predefined prefix and length.
    "! @parameter iv_number | Raw numeric input
    "! @parameter rv_code   | Formatted Business Partner code
    CLASS-METHODS format_bp_code
      IMPORTING
        iv_number      TYPE simple
      RETURNING
        VALUE(rv_code) TYPE string.

    "! Convenience formatter for Item code using predefined prefix and length.
    "! @parameter iv_number | Raw numeric input
    "! @parameter rv_code   | Formatted Item code
    CLASS-METHODS format_item_code
      IMPORTING
        iv_number      TYPE simple
      RETURNING
        VALUE(rv_code) TYPE string.

    "! Convenience formatter for Item Group code using predefined prefix and length.
    "! @parameter iv_number | Raw numeric input
    "! @parameter rv_code   | Formatted Item Group code
    CLASS-METHODS format_item_grp_code
      IMPORTING
        iv_number      TYPE simple
      RETURNING
        VALUE(rv_code) TYPE string.

    "! Convenience formatter for VAT code using predefined prefix and length.
    "! @parameter iv_number | Raw numeric input
    "! @parameter rv_code   | Formatted VAT code
    CLASS-METHODS format_vat_code
      IMPORTING
        iv_number      TYPE simple
      RETURNING
        VALUE(rv_code) TYPE string.

    "! Convenience formatter for Warehouse code using predefined prefix and length.
    "! @parameter iv_number | Raw numeric input
    "! @parameter rv_code   | Formatted Warehouse code
    CLASS-METHODS format_warehouse_code
      IMPORTING
        iv_number      TYPE simple
      RETURNING
        VALUE(rv_code) TYPE string.

    " NRO Setup & Administration
    "! BTP ABAP Cloud: Initializes number range interval '01' for all configured NRO objects.
    CLASS-METHODS setup_intervals.

    "! Resets all NRO intervals back to level zero for seeding or environment reset.
    CLASS-METHODS reset_intervals.

    "! Synchronizes current NRO interval levels with actual active database record counts.
    CLASS-METHODS sync_intervals_from_db.

    "! Synchronizes Business Partner NRO interval level with actual active database record count.
    CLASS-METHODS sync_bp_interval.

    "! Synchronizes Item NRO interval level with actual active database record count.
    CLASS-METHODS sync_item_interval.

    "! Synchronizes Item Group NRO interval level with actual active database record count.
    CLASS-METHODS sync_item_grp_interval.

    "! Synchronizes VAT NRO interval level with actual active database record count.
    CLASS-METHODS sync_vat_interval.

    "! Synchronizes Warehouse NRO interval level with actual active database record count.
    CLASS-METHODS sync_warehouse_interval.

  PRIVATE SECTION.

    " Internal Helpers
    "! Generic sequential number generator based on entity metadata.
    CLASS-METHODS get_next_number
      IMPORTING
        is_meta          TYPE zif_merp_constants=>ty_entity_metadata
      RETURNING
        VALUE(rv_number) TYPE string
      RAISING
        cx_number_ranges.

    "! Queries highest current key from specified database table matching prefix pattern.
    CLASS-METHODS get_max_code_from_db
      IMPORTING
        iv_table       TYPE string
        iv_field       TYPE string
        iv_prefix      TYPE string
      RETURNING
        VALUE(rv_code) TYPE string.

    "! Extracts and converts numeric suffix from string key after prefix offset.
    CLASS-METHODS extract_numeric_suffix
      IMPORTING
        iv_code           TYPE string
        iv_offset         TYPE i
      RETURNING
        VALUE(rv_numeric) TYPE int8.

    "! Generic number generator wrapping Standard SAP Number Range Runtime API based on entity metadata.
    CLASS-METHODS get_next_number_from_nro
      IMPORTING
        is_meta        TYPE zif_merp_constants=>ty_entity_metadata
      RETURNING
        VALUE(rv_code) TYPE string.

    "! Returns list of all configured NRO object names for administration.
    CLASS-METHODS get_nro_objects
      RETURNING
        VALUE(rt_objects) TYPE string_table.

    "! Saves or updates NRO interval '01' level for specified object.
    CLASS-METHODS save_interval
      IMPORTING
        iv_object TYPE cl_numberrange_intervals=>nr_object
        iv_level  TYPE int8 DEFAULT 0.

    "! Reads maximum numeric suffix from database for specific entity metadata.
    CLASS-METHODS get_max_level_from_db
      IMPORTING
        is_meta         TYPE zif_merp_constants=>ty_entity_metadata
      RETURNING
        VALUE(rv_level) TYPE int8.

ENDCLASS.

CLASS zcl_merp_num_range_util IMPLEMENTATION.

  METHOD get_next_bp_code.
    rv_bp_code = get_next_number( zif_merp_constants=>c_bp ).
  ENDMETHOD.

  METHOD get_next_item_code.
    rv_item_code = get_next_number( zif_merp_constants=>c_item ).
  ENDMETHOD.

  METHOD get_next_item_group_code.
    rv_item_group_code = get_next_number( zif_merp_constants=>c_ig ).
  ENDMETHOD.

  METHOD get_next_vat_code.
    rv_vat_code = get_next_number( zif_merp_constants=>c_vat ).
  ENDMETHOD.

  METHOD get_next_warehouse_code.
    rv_wh_id = get_next_number( zif_merp_constants=>c_wh ).
  ENDMETHOD.

  METHOD get_next_bp_code_nro.
    rv_bp_code = get_next_number_from_nro( zif_merp_constants=>c_bp ).

    IF rv_bp_code IS INITIAL.
      rv_bp_code = get_next_bp_code( ).
    ENDIF.
  ENDMETHOD.

  METHOD get_next_item_code_nro.
    rv_item_code = get_next_number_from_nro( zif_merp_constants=>c_item ).

    IF rv_item_code IS INITIAL.
      rv_item_code = get_next_item_code( ).
    ENDIF.
  ENDMETHOD.

  METHOD get_next_item_group_code_nro.
    rv_item_group_code = get_next_number_from_nro( zif_merp_constants=>c_ig ).

    IF rv_item_group_code IS INITIAL.
      rv_item_group_code = get_next_item_group_code( ).
    ENDIF.
  ENDMETHOD.

  METHOD get_next_vat_code_nro.
    rv_vat_code = get_next_number_from_nro( zif_merp_constants=>c_vat ).

    IF rv_vat_code IS INITIAL.
      rv_vat_code = get_next_vat_code( ).
    ENDIF.
  ENDMETHOD.

  METHOD get_next_warehouse_code_nro.
    rv_wh_id = get_next_number_from_nro( zif_merp_constants=>c_wh ).

    IF rv_wh_id IS INITIAL.
      rv_wh_id = get_next_warehouse_code( ).
    ENDIF.
  ENDMETHOD.

  METHOD add_leading_zeros.
    rv_code = |{ iv_value WIDTH = iv_length PAD = '0' ALIGN = RIGHT }|.
  ENDMETHOD.

  METHOD format_code.

    " Ignore negative numeric values
    TRY.
        IF CONV int8( iv_number ) < 0.
          RETURN.
        ENDIF.
      CATCH cx_sy_conversion_error cx_sy_arithmetic_overflow.
        RETURN.
    ENDTRY.

    DATA(lv_numeric_length) = iv_total_length - strlen( iv_prefix ).

    TRY.
        IF lv_numeric_length > 0
           AND CONV int8( iv_number ) >= ipow( base = 10 exp = lv_numeric_length ).
          RETURN.
        ENDIF.
      CATCH cx_sy_arithmetic_overflow cx_sy_conversion_error.
        RETURN.
    ENDTRY.

    DATA(lv_padded) = COND string(
      WHEN lv_numeric_length > 0
      THEN add_leading_zeros(
             iv_value  = iv_number
             iv_length = lv_numeric_length )
      ELSE |{ iv_number }| ).

    rv_code = |{ iv_prefix }{ lv_padded }|.
  ENDMETHOD.

  METHOD format_bp_code.
    rv_code = format_code(
      iv_number       = iv_number
      iv_prefix       = zif_merp_constants=>c_bp-prefix
      iv_total_length = zif_merp_constants=>c_bp-length ).
  ENDMETHOD.

  METHOD format_item_code.
    rv_code = format_code(
      iv_number       = iv_number
      iv_prefix       = zif_merp_constants=>c_item-prefix
      iv_total_length = zif_merp_constants=>c_item-length ).
  ENDMETHOD.

  METHOD format_item_grp_code.
    rv_code = format_code(
      iv_number       = iv_number
      iv_prefix       = zif_merp_constants=>c_ig-prefix
      iv_total_length = zif_merp_constants=>c_ig-length ).
  ENDMETHOD.

  METHOD format_vat_code.
    rv_code = format_code(
      iv_number       = iv_number
      iv_prefix       = zif_merp_constants=>c_vat-prefix
      iv_total_length = zif_merp_constants=>c_vat-length ).
  ENDMETHOD.

  METHOD format_warehouse_code.
    rv_code = format_code(
      iv_number       = iv_number
      iv_prefix       = zif_merp_constants=>c_wh-prefix
      iv_total_length = zif_merp_constants=>c_wh-length ).
  ENDMETHOD.

  METHOD setup_intervals.
    DATA(lt_objects) = get_nro_objects( ).

    LOOP AT lt_objects ASSIGNING FIELD-SYMBOL(<lv_object>).
      save_interval(
        iv_object = CONV #( <lv_object> )
        iv_level  = 0 ).
    ENDLOOP.
  ENDMETHOD.

  METHOD reset_intervals.
    DATA(lt_objects) = get_nro_objects( ).

    LOOP AT lt_objects ASSIGNING FIELD-SYMBOL(<lv_object>).
      save_interval(
        iv_object = CONV #( <lv_object> )
        iv_level  = 0 ).
    ENDLOOP.
  ENDMETHOD.

  METHOD sync_intervals_from_db.
    sync_bp_interval( ).
    sync_item_interval( ).
    sync_item_grp_interval( ).
    sync_vat_interval( ).
    sync_warehouse_interval( ).
  ENDMETHOD.

  METHOD sync_bp_interval.
    save_interval(
      iv_object = zif_merp_constants=>c_bp-number_object
      iv_level  = get_max_level_from_db( zif_merp_constants=>c_bp ) ).
  ENDMETHOD.

  METHOD sync_item_interval.
    save_interval(
      iv_object = zif_merp_constants=>c_item-number_object
      iv_level  = get_max_level_from_db( zif_merp_constants=>c_item ) ).
  ENDMETHOD.

  METHOD sync_item_grp_interval.
    save_interval(
      iv_object = zif_merp_constants=>c_ig-number_object
      iv_level  = get_max_level_from_db( zif_merp_constants=>c_ig ) ).
  ENDMETHOD.

  METHOD sync_vat_interval.
    save_interval(
      iv_object = zif_merp_constants=>c_vat-number_object
      iv_level  = get_max_level_from_db( zif_merp_constants=>c_vat ) ).
  ENDMETHOD.

  METHOD sync_warehouse_interval.
    save_interval(
      iv_object = zif_merp_constants=>c_wh-number_object
      iv_level  = get_max_level_from_db( zif_merp_constants=>c_wh ) ).
  ENDMETHOD.

  METHOD save_interval.
    DATA: lt_interval TYPE TABLE OF cl_numberrange_intervals=>nr_nriv_line,
          ls_interval LIKE LINE OF lt_interval,
          lv_error    TYPE cl_numberrange_intervals=>nr_error,
          ls_error    TYPE cl_numberrange_intervals=>nr_error_inf.

    ls_interval-nrrangenr  = '01'.
    ls_interval-fromnumber = '0000000001'.
    ls_interval-tonumber   = '9999999999'.
    ls_interval-nrlevel    = add_leading_zeros( iv_value = iv_level iv_length = 10 ).
    APPEND ls_interval TO lt_interval.

    TRY.
        cl_numberrange_intervals=>update(
          EXPORTING
            object   = iv_object
            interval = lt_interval
          IMPORTING
            error     = lv_error
            error_inf = ls_error ).

      CATCH cx_number_ranges.
        TRY.
            cl_numberrange_intervals=>create(
              EXPORTING
                object   = iv_object
                interval = lt_interval
              IMPORTING
                error     = lv_error
                error_inf = ls_error ).
          CATCH cx_number_ranges cx_root.
            RETURN.
        ENDTRY.
      CATCH cx_root.
        RETURN.
    ENDTRY.

  ENDMETHOD.

  METHOD get_max_level_from_db.
    DATA(lv_max_code) = get_max_code_from_db(
      iv_table  = is_meta-table_db
      iv_field  = is_meta-field_db
      iv_prefix = is_meta-prefix ).

    rv_level = extract_numeric_suffix(
      iv_code   = lv_max_code
      iv_offset = strlen( is_meta-prefix ) ).
  ENDMETHOD.

  METHOD get_next_number.
    DATA(lv_prefix_length) = strlen( is_meta-prefix ).

    DATA(lv_max_active) = get_max_code_from_db(
      iv_table  = is_meta-table_db
      iv_field  = is_meta-field_db
      iv_prefix = is_meta-prefix ).

    DATA(lv_max_draft) = COND string(
      WHEN is_meta-table_draft IS NOT INITIAL
       AND is_meta-field_draft IS NOT INITIAL
      THEN get_max_code_from_db(
             iv_table  = is_meta-table_draft
             iv_field  = is_meta-field_draft
             iv_prefix = is_meta-prefix ) ).

    DATA(lv_max_numeric) = nmax(
      val1 = extract_numeric_suffix(
               iv_code   = lv_max_active
               iv_offset = lv_prefix_length )
      val2 = extract_numeric_suffix(
               iv_code   = lv_max_draft
               iv_offset = lv_prefix_length ) ).

    lv_max_numeric += 1.

    rv_number = format_code(
      iv_prefix       = is_meta-prefix
      iv_number       = lv_max_numeric
      iv_total_length = is_meta-length ).

    " Raise standard number range exception if sequence is exhausted or invalid
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

    TRY.
        " Case-insensitive match for both UPPER and lower prefix variants
        DATA(lv_where) = |( { iv_field } LIKE '{ lv_prefix_upper }%' OR { iv_field } LIKE '{ lv_prefix_lower }%' )|.
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

  METHOD get_next_number_from_nro.
    DATA: lv_raw_number TYPE cl_numberrange_runtime=>nr_number.

    TRY.
        cl_numberrange_runtime=>number_get(
          EXPORTING
            nr_range_nr = '01'
            object      = is_meta-number_object
          IMPORTING
            number      = lv_raw_number ).

        TRY.
            rv_code = format_code(
              iv_number       = CONV int8( lv_raw_number )
              iv_prefix       = is_meta-prefix
              iv_total_length = is_meta-length ).
          CATCH cx_sy_conversion_error cx_sy_arithmetic_overflow.
            CLEAR rv_code.
        ENDTRY.

      CATCH cx_number_ranges.
        CLEAR rv_code.
    ENDTRY.
  ENDMETHOD.

  METHOD get_nro_objects.
    rt_objects = VALUE #(
      ( CONV string( zif_merp_constants=>c_bp-number_object ) )
      ( CONV string( zif_merp_constants=>c_item-number_object ) )
      ( CONV string( zif_merp_constants=>c_ig-number_object ) )
      ( CONV string( zif_merp_constants=>c_vat-number_object ) )
      ( CONV string( zif_merp_constants=>c_wh-number_object ) )
    ).
  ENDMETHOD.

ENDCLASS.
