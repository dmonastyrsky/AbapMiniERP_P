CLASS zcl_merp_md_util DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_dependency_result,
             key_value TYPE string,
             msg       TYPE REF TO zcx_merp_base,
           END OF ty_dependency_result,
           tt_dependency_results TYPE STANDARD TABLE OF ty_dependency_result WITH EMPTY KEY.

    "! Checks dependencies for any BO entity against its usage CDS view.
    "! @parameter it_keys          | List of key values to validate
    "! @parameter iv_usage_cds     | Name of the usage CDS View
    "! @parameter iv_key_field_name| Key field name in CDS View
    "! @parameter is_textid        | Message textid structure from exception classes
    "! @parameter rt_blocked_keys  | Collection of blocked key strings with prepared error message objects
    CLASS-METHODS check_dependencies
      IMPORTING
        it_keys                TYPE string_table
        iv_usage_cds           TYPE string
        iv_key_field_name      TYPE string
        is_textid              TYPE scx_t100key
      RETURNING
        VALUE(rt_blocked_keys) TYPE tt_dependency_results.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_merp_md_util IMPLEMENTATION.

  METHOD check_dependencies.
    IF it_keys IS INITIAL OR iv_usage_cds IS INITIAL OR iv_key_field_name IS INITIAL.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_dep,
             key_field    TYPE string,
             usedinentity TYPE zmerp_entity_name,
           END OF ty_dep.

    TYPES tt_string_range TYPE RANGE OF string.

    DATA lt_keys         TYPE SORTED TABLE OF string WITH NON-UNIQUE KEY table_line.
    DATA lt_dependencies TYPE STANDARD TABLE OF ty_dep WITH EMPTY KEY.

    lt_keys = it_keys.
    DELETE ADJACENT DUPLICATES FROM lt_keys.

    DATA(lv_select_clause) = |{ iv_key_field_name } AS key_field, UsedInEntity|.
    DATA(lv_total_lines)   = lines( lt_keys ).
    DATA(lv_offset)        = 1.

    CONSTANTS lc_batch_size TYPE i VALUE 500.

    TRY.
        WHILE lv_offset <= lv_total_lines.

          DATA(lt_batch_range) = VALUE tt_string_range(
            FOR idx = lv_offset WHILE idx < lv_offset + lc_batch_size AND idx <= lv_total_lines
            ( sign = 'I' option = 'EQ' low = lt_keys[ idx ] )
          ).

          DATA(lv_where_clause) = |{ iv_key_field_name } IN @lt_batch_range|.

          SELECT DISTINCT (lv_select_clause)
            FROM (iv_usage_cds)
            WHERE (lv_where_clause)
            APPENDING TABLE @lt_dependencies.

          lv_offset = lv_offset + lc_batch_size.
        ENDWHILE.

      CATCH cx_sy_dynamic_osql_error cx_root INTO DATA(lx_err).
        LOOP AT lt_keys INTO DATA(lv_failed_key).
          INSERT VALUE #(
            key_value = lv_failed_key
            msg       = NEW zcx_merp_md(
                          textid   = is_textid
                          attr1    = lv_failed_key
                          attr2    = CONV #( lx_err->get_text( ) )
                          severity = if_abap_behv_message=>severity-error )
          ) INTO TABLE rt_blocked_keys.
        ENDLOOP.
        RETURN.
    ENDTRY.

    IF lt_dependencies IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_dependencies REFERENCE INTO DATA(lr_dep).
      INSERT VALUE #(
        key_value = lr_dep->key_field
        msg       = NEW zcx_merp_md(
                      textid   = is_textid
                      attr1    = lr_dep->key_field
                      attr2    = CONV #( lr_dep->usedinentity )
                      severity = if_abap_behv_message=>severity-error )
      ) INTO TABLE rt_blocked_keys.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
