CLASS zcl_merp_nro_admin_util DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_merp_constants.

    "! Generic number generator wrapping Standard SAP Number Range Runtime API based on entity metadata.
    CLASS-METHODS get_next_number_from_nro
      IMPORTING
        is_meta            TYPE zif_merp_constants=>ty_entity_metadata
        iv_company_code    TYPE zmerp_company_code OPTIONAL
        iv_prefix_override TYPE string OPTIONAL
      RETURNING
        VALUE(rv_code)     TYPE string.

    "! Generic bulk number generator wrapping Standard SAP NRO Runtime API based on entity metadata.
    CLASS-METHODS get_next_numbers_from_nro
      IMPORTING
        is_meta            TYPE zif_merp_constants=>ty_entity_metadata
        iv_count           TYPE i
        iv_company_code    TYPE zmerp_company_code OPTIONAL
        iv_prefix_override TYPE string OPTIONAL
      RETURNING
        VALUE(rt_codes)    TYPE string_table.

    "! BTP ABAP Cloud: Initializes number range interval '01' for all Master Data and Document NRO objects.
    CLASS-METHODS setup_intervals
      IMPORTING
        iv_level TYPE int8 DEFAULT 0.

    "! Resets all Master Data and Document NRO intervals back to level zero.
    CLASS-METHODS reset_intervals.

    "! Initializes number range interval '01' for all Master Data NRO objects.
    CLASS-METHODS setup_master_intervals
      IMPORTING
        iv_level TYPE int8 DEFAULT 0.

    "! Resets all Master Data NRO intervals back to level zero.
    CLASS-METHODS reset_master_intervals.

    "! Initializes subobject NRO intervals for all document NRO objects across all active company codes.
    CLASS-METHODS setup_doc_intervals.

    "! Resets subobject NRO intervals back to zero for all document NRO objects across all active company codes.
    CLASS-METHODS reset_doc_intervals.

    "! Saves or updates NRO interval '01' level for specified object and subobject.
    CLASS-METHODS save_interval
      IMPORTING
        iv_object    TYPE cl_numberrange_intervals=>nr_object
        iv_subobject TYPE cl_numberrange_intervals=>nr_subobject OPTIONAL
        iv_level     TYPE int8 DEFAULT 0.

    "! Returns list of Master Data NRO object names (global objects).
    CLASS-METHODS get_master_nro_objects
      RETURNING
        VALUE(rt_objects) TYPE string_table.

    "! Returns list of Transactional Document NRO object names (subobject-based).
    CLASS-METHODS get_doc_nro_objects
      RETURNING
        VALUE(rt_objects) TYPE string_table.

ENDCLASS.

CLASS zcl_merp_nro_admin_util IMPLEMENTATION.

  METHOD get_next_number_from_nro.
    DATA: lv_raw_number TYPE cl_numberrange_runtime=>nr_number.

    DATA(lv_prefix) = COND string(
      WHEN iv_prefix_override IS SUPPLIED AND iv_prefix_override IS NOT INITIAL
      THEN iv_prefix_override
      ELSE is_meta-prefix ).

    TRY.
        cl_numberrange_runtime=>number_get(
          EXPORTING
            nr_range_nr = '01'
            object      = is_meta-number_object
            subobject   = CONV #( iv_company_code )
          IMPORTING
            number      = lv_raw_number ).

        TRY.
            rv_code = zcl_merp_format_util=>format_code(
              iv_number       = CONV int8( lv_raw_number )
              iv_prefix       = lv_prefix
              iv_total_length = is_meta-length ).
          CATCH cx_sy_conversion_error cx_sy_arithmetic_overflow.
            CLEAR rv_code.
        ENDTRY.

      CATCH cx_number_ranges.
        CLEAR rv_code.
    ENDTRY.
  ENDMETHOD.

  METHOD get_next_numbers_from_nro.
    DATA lv_raw_number TYPE cl_numberrange_runtime=>nr_number.

    IF iv_count <= 0.
      RETURN.
    ENDIF.

    DATA(lv_prefix) = COND string(
      WHEN iv_prefix_override IS SUPPLIED AND iv_prefix_override IS NOT INITIAL
      THEN iv_prefix_override
      ELSE is_meta-prefix ).

    TRY.
        cl_numberrange_runtime=>number_get(
          EXPORTING
            nr_range_nr = '01'
            object      = is_meta-number_object
            subobject   = CONV #( iv_company_code )
            quantity    = CONV #( iv_count )
          IMPORTING
            number      = lv_raw_number ).

        DATA(lv_last_num) = CONV int8( lv_raw_number ).
        DATA(lv_start_num) = lv_last_num - iv_count + 1.

        DO iv_count TIMES.
          DATA(lv_curr_num) = lv_start_num + sy-index - 1.
          DATA(lv_code) = zcl_merp_format_util=>format_code(
            iv_number       = lv_curr_num
            iv_prefix       = lv_prefix
            iv_total_length = is_meta-length ).

          IF lv_code IS INITIAL.
            CLEAR rt_codes.
            RETURN.
          ENDIF.

          APPEND lv_code TO rt_codes.
        ENDDO.

      CATCH cx_number_ranges cx_sy_conversion_error cx_sy_arithmetic_overflow.
        CLEAR rt_codes.
    ENDTRY.
  ENDMETHOD.

  METHOD setup_intervals.
    setup_master_intervals( iv_level = iv_level ).
    setup_doc_intervals( ).
  ENDMETHOD.

  METHOD reset_intervals.
    reset_master_intervals( ).
    reset_doc_intervals( ).
  ENDMETHOD.

  METHOD setup_master_intervals.
    DATA(lt_objects) = get_master_nro_objects( ).

    LOOP AT lt_objects ASSIGNING FIELD-SYMBOL(<lv_object>).
      save_interval(
        iv_object = CONV #( <lv_object> )
        iv_level  = iv_level ).
    ENDLOOP.
  ENDMETHOD.

  METHOD reset_master_intervals.
    DATA(lt_objects) = get_master_nro_objects( ).

    LOOP AT lt_objects ASSIGNING FIELD-SYMBOL(<lv_object>).
      save_interval(
        iv_object = CONV #( <lv_object> )
        iv_level  = 0 ).
    ENDLOOP.
  ENDMETHOD.

  METHOD setup_doc_intervals.
    SELECT company_code
      FROM zmerp_comp_code
      WHERE is_blocked = @abap_false
      INTO TABLE @DATA(lt_companies).

    IF lt_companies IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_doc_objects) = get_doc_nro_objects( ).

    LOOP AT lt_doc_objects ASSIGNING FIELD-SYMBOL(<lv_doc_object>).
      LOOP AT lt_companies ASSIGNING FIELD-SYMBOL(<ls_company>).
        save_interval(
          iv_object    = CONV #( <lv_doc_object> )
          iv_subobject = CONV #( <ls_company>-company_code )
          iv_level     = 0 ).
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD reset_doc_intervals.
    SELECT company_code
      FROM zmerp_comp_code
      WHERE is_blocked = @abap_false
      INTO TABLE @DATA(lt_companies).

    IF lt_companies IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_doc_objects) = get_doc_nro_objects( ).

    LOOP AT lt_doc_objects ASSIGNING FIELD-SYMBOL(<lv_doc_object>).
      LOOP AT lt_companies ASSIGNING FIELD-SYMBOL(<ls_company>).
        save_interval(
          iv_object    = CONV #( <lv_doc_object> )
          iv_subobject = CONV #( <ls_company>-company_code )
          iv_level     = 0 ).
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD save_interval.
    DATA: lt_interval TYPE TABLE OF cl_numberrange_intervals=>nr_nriv_line,
          ls_interval LIKE LINE OF lt_interval,
          lv_error    TYPE cl_numberrange_intervals=>nr_error,
          ls_error    TYPE cl_numberrange_intervals=>nr_error_inf.

    ls_interval-subobject  = iv_subobject.
    ls_interval-nrrangenr  = '01'.
    ls_interval-fromnumber = '0000000001'.
    ls_interval-tonumber   = '9999999999'.
    ls_interval-nrlevel    = zcl_merp_format_util=>add_leading_zeros( iv_value = iv_level iv_length = 10 ).
    APPEND ls_interval TO lt_interval.

    TRY.
        cl_numberrange_intervals=>update(
          EXPORTING
            object    = iv_object
            subobject = iv_subobject
            interval  = lt_interval
          IMPORTING
            error     = lv_error
            error_inf = ls_error ).

      CATCH cx_number_ranges.
        TRY.
            cl_numberrange_intervals=>create(
              EXPORTING
                object    = iv_object
                subobject = iv_subobject
                interval  = lt_interval
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

  METHOD get_master_nro_objects.
    rt_objects = VALUE #(
      ( CONV string( zif_merp_constants=>c_bp-number_object ) )
      ( CONV string( zif_merp_constants=>c_item-number_object ) )
      ( CONV string( zif_merp_constants=>c_ig-number_object ) )
      ( CONV string( zif_merp_constants=>c_vat-number_object ) )
      ( CONV string( zif_merp_constants=>c_wh-number_object ) )
    ).
  ENDMETHOD.

  METHOD get_doc_nro_objects.
    rt_objects = VALUE #(
      ( CONV string( zif_merp_constants=>c_po-number_object ) )
    ).
  ENDMETHOD.

ENDCLASS.
