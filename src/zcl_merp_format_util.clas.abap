CLASS zcl_merp_format_util DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

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

ENDCLASS.
