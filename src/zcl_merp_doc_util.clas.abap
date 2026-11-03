CLASS zcl_merp_doc_util DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_generic_header_defaults,
        document_date TYPE zmerp_doc_date,
      END OF ty_generic_header_defaults.

    CLASS-METHODS get_generic_header_defaults
      RETURNING
        VALUE(rs_defaults) TYPE ty_generic_header_defaults.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_merp_doc_util IMPLEMENTATION.

  METHOD get_generic_header_defaults.
    rs_defaults = VALUE #(
      document_date = cl_abap_context_info=>get_system_date( )
    ).
  ENDMETHOD.

ENDCLASS.
