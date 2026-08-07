CLASS zcl_merp_clear_all_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun .

    CLASS-METHODS execute
      IMPORTING
        out TYPE REF TO if_oo_adt_classrun_out OPTIONAL .

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-METHODS clear_entity
      IMPORTING
        iv_label      TYPE string
        iv_active_tab TYPE tabname
        iv_draft_tab  TYPE tabname OPTIONAL
        out           TYPE REF TO if_oo_adt_classrun_out OPTIONAL .

    CLASS-METHODS clear_table
      IMPORTING
        iv_table_name TYPE tabname
        iv_label      TYPE string
        out           TYPE REF TO if_oo_adt_classrun_out OPTIONAL .
ENDCLASS.

CLASS zcl_merp_clear_all_data IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    execute( out ).
  ENDMETHOD.

  METHOD execute.
    IF out IS BOUND.
      out->write( '==================================================' ).
      out->write( '  Starting Mini ERP Full Data Cleanup Process     ' ).
      out->write( '==================================================' ).
    ENDIF.

    " Clear entities using structured metadata constants from zif_merp_constants
    clear_entity(
      iv_label      = 'Business Partner'
      iv_active_tab = CONV tabname( zif_merp_constants=>c_bp-table_db )
      iv_draft_tab  = CONV tabname( zif_merp_constants=>c_bp-table_draft )
      out           = out ).

    clear_entity(
      iv_label      = 'Item'
      iv_active_tab = CONV tabname( zif_merp_constants=>c_item-table_db )
      iv_draft_tab  = CONV tabname( zif_merp_constants=>c_item-table_draft )
      out           = out ).

    clear_entity(
      iv_label      = 'Item Group'
      iv_active_tab = CONV tabname( zif_merp_constants=>c_ig-table_db )
      iv_draft_tab  = CONV tabname( zif_merp_constants=>c_ig-table_draft )
      out           = out ).

    clear_entity(
      iv_label      = 'Warehouse'
      iv_active_tab = CONV tabname( zif_merp_constants=>c_wh-table_db )
      iv_draft_tab  = CONV tabname( zif_merp_constants=>c_wh-table_draft )
      out           = out ).

    clear_entity(
      iv_label      = 'VAT Rate'
      iv_active_tab = CONV tabname( zif_merp_constants=>c_vat-table_db )
      iv_draft_tab  = CONV tabname( zif_merp_constants=>c_vat-table_draft )
      out           = out ).

    clear_entity(
      iv_label      = 'Company Code'
      iv_active_tab = CONV tabname( zif_merp_constants=>c_comp-table_db )
      iv_draft_tab  = CONV tabname( zif_merp_constants=>c_comp-table_draft )
      out           = out ).

    IF out IS BOUND.
      out->write( '==================================================' ).
      out->write( '  Full Data Cleanup Completed Successfully!       ' ).
      out->write( '==================================================' ).
    ENDIF.
  ENDMETHOD.

  METHOD clear_entity.
    " 1. Clear Draft table if specified
    IF iv_draft_tab IS NOT INITIAL.
      clear_table(
        iv_table_name = iv_draft_tab
        iv_label      = |Draft { iv_label }|
        out           = out ).
    ENDIF.

    " 2. Clear Active table
    clear_table(
      iv_table_name = iv_active_tab
      iv_label      = iv_label
      out           = out ).
  ENDMETHOD.

  METHOD clear_table.
    IF iv_table_name IS INITIAL.
      RETURN.
    ENDIF.

    " Dynamic SQL execution
    DELETE FROM (iv_table_name).

    IF out IS BOUND.
      out->write( |[{ iv_label } ({ iv_table_name })]: Deleted { sy-dbcnt } rows.| ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
