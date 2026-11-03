"! Master Data Business Logic Validator for Custom ERP.
"! This class centralizes all business logic validations and structural integrity
"! checks across Master Data entities, decoupling rules from RAP behavior pools.
CLASS zcl_merp_md_validator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Validates if the given VAT percentage is within the acceptable business range (0% to 100%).
    "! @parameter iv_percentage | The VAT percentage value to be validated
    "! @parameter rv_is_valid   | Returns abap_true if valid, otherwise abap_false
    CLASS-METHODS is_vat_percentage_valid
      IMPORTING iv_percentage     TYPE zmerp_vat_percentage
      RETURNING VALUE(rv_is_valid) TYPE abap_bool.

    "! Validates if the company prefix has the correct mandatory length.
    "! @parameter iv_prefix   | The company prefix string to be validated
    "! @parameter rv_is_valid | Returns abap_true if length is exactly 2 characters, otherwise abap_false
    CLASS-METHODS is_company_prefix_valid
      IMPORTING iv_prefix         TYPE zmerp_company_prefix
      RETURNING VALUE(rv_is_valid) TYPE abap_bool.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_merp_md_validator IMPLEMENTATION.

  METHOD is_vat_percentage_valid.
    " Standard European ERP tax configuration constraint (0.00% to 100.00%)
    IF iv_percentage >= 0 AND iv_percentage <= 100.
      rv_is_valid = abap_true.
    ELSE.
      rv_is_valid = abap_false.
    ENDIF.
  ENDMETHOD.

  METHOD is_company_prefix_valid.
    " Corporate standard requirement: Company Prefix must be exactly 2 characters long
    IF numofchar( condense( iv_prefix ) ) = 2.
      rv_is_valid = abap_true.
    ELSE.
      rv_is_valid = abap_false.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

