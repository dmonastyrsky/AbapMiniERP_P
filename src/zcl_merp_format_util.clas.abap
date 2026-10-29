CLASS zcl_merp_format_util DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_merp_constants.

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

    "! Convenience formatter for Purchase Order number using dynamic company prefix.
    "! @parameter iv_number       | Raw numeric input
    "! @parameter iv_company_code | Company code context
    "! @parameter rv_code         | Formatted Purchase Order number
    CLASS-METHODS format_po_code
      IMPORTING
        iv_number       TYPE simple
        iv_company_code TYPE zmerp_company_code
      RETURNING
        VALUE(rv_code)  TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.

ENDCLASS.

CLASS zcl_merp_format_util IMPLEMENTATION.

  METHOD add_leading_zeros.
    rv_code = |{ iv_value WIDTH = iv_length PAD = '0' ALIGN = RIGHT }|.
  ENDMETHOD.

  METHOD format_code.
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

  METHOD format_po_code.
    TRY.
        DATA(ls_company) = NEW zcl_merp_md_comp_code_sel( )->zif_merp_md_comp_code_sel~read_company( iv_company_code ).
        DATA(lv_prefix)  = ls_company-CompanyPrefix.
      CATCH zcx_merp_md.
        CLEAR lv_prefix.
    ENDTRY.

    rv_code = format_code(
      iv_number       = iv_number
      iv_prefix       = CONV #( lv_prefix )
      iv_total_length = zif_merp_constants=>c_po-length ).
  ENDMETHOD.

ENDCLASS.
