"! Document Business Logic Validator for Custom ERP.
"! Centralizes transactional validations for both Purchasing and Sales workflows.
CLASS zcl_merp_doc_validator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_item_duplicate,
             HeaderUUID TYPE sysuuid_x16,
             ItemCode   TYPE zmerp_item_code,
           END OF ty_item_duplicate.
    TYPES tt_item_duplicates TYPE HASHED TABLE OF ty_item_duplicate WITH UNIQUE KEY HeaderUUID ItemCode.
    TYPES tt_item_fields     TYPE STANDARD TABLE OF ty_item_duplicate WITH EMPTY KEY.

    "! Validates if the given Document Date is not in the future.
    "! @parameter iv_doc_date | The document date to be validated
    "! @parameter iv_today    | Current system date context
    "! @parameter rv_is_valid | Returns abap_true if valid, otherwise abap_false
    CLASS-METHODS is_document_date_valid
      IMPORTING iv_doc_date       TYPE zmerp_doc_date
                iv_today          TYPE d
      RETURNING VALUE(rv_is_valid) TYPE abap_bool.

    "! Validates if the Posting Date correctly follows the Document Date.
    "! @parameter iv_doc_date  | Document date anchor
    "! @parameter iv_post_date | Posting date to be validated
    "! @parameter rv_is_valid  | Returns abap_true if valid, otherwise abap_false
    CLASS-METHODS is_posting_date_valid
      IMPORTING iv_doc_date       TYPE zmerp_doc_date
                iv_post_date      TYPE zmerp_posting_date
      RETURNING VALUE(rv_is_valid) TYPE abap_bool.

    "! Validates if the logistical Delivery Date correctly follows the Document Date.
    "! @parameter iv_doc_date  | Document date anchor
    "! @parameter iv_del_date  | Logistical delivery date to be validated
    "! @parameter rv_is_valid  | Returns abap_true if valid, otherwise abap_false
    CLASS-METHODS is_delivery_date_valid
      IMPORTING iv_doc_date       TYPE zmerp_doc_date
                iv_del_date       TYPE zmerp_delivery_date
      RETURNING VALUE(rv_is_valid) TYPE abap_bool.

    "! Validates if the specific business partner is flagged as a supplier.
    "! @parameter iv_is_supplier | The supplier flag from master data
    "! @parameter rv_is_valid    | Returns abap_true if partner is a supplier, otherwise abap_false
    CLASS-METHODS is_pur_partner_supplier
      IMPORTING iv_is_supplier    TYPE zmerp_bus_part_is_supplier
      RETURNING VALUE(rv_is_valid) TYPE abap_bool.

    "! Validates if the specific business partner is flagged as a customer.
    "! @parameter iv_is_customer | The customer flag from master data
    "! @parameter rv_is_valid    | Returns abap_true if partner is a customer, otherwise abap_false
    CLASS-METHODS is_sd_partner_customer
      IMPORTING iv_is_customer    TYPE zmerp_bus_part_is_customer
      RETURNING VALUE(rv_is_valid) TYPE abap_bool.

    "! Validates if the item quantity is positive and strictly greater than zero.
    "! @parameter iv_quantity | The item quantity to validate
    "! @parameter rv_is_valid | Returns abap_true if valid, otherwise abap_false
    CLASS-METHODS is_item_quantity_valid
      IMPORTING iv_quantity       TYPE zmerp_quantity
      RETURNING VALUE(rv_is_valid) TYPE abap_bool.

    "! Validates if the item unit price is positive and strictly greater than zero.
    "! @parameter iv_price    | The item price to validate
    "! @parameter rv_is_valid | Returns abap_true if valid, otherwise abap_false
    CLASS-METHODS is_item_price_valid
      IMPORTING iv_price          TYPE zmerp_price
      RETURNING VALUE(rv_is_valid) TYPE abap_bool.

    "! Identifies duplicate item codes within their respective document contexts.
    "! Processes the transactional buffer using a temporary lookup sequence to catch duplicates.
    "! @parameter it_items       | The complete transactional collection of items to check (accepts any table structure)
    "! @parameter rt_duplicates | Returns unique combinations of HeaderUUID and ItemCode that appear multiple times
    CLASS-METHODS get_duplicate_item_codes
      IMPORTING it_items             TYPE tt_item_fields
      RETURNING VALUE(rt_duplicates) TYPE tt_item_duplicates.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_merp_doc_validator IMPLEMENTATION.

  METHOD is_document_date_valid.
    " Standard ERP constraint: Document creation in the future is invalid
    rv_is_valid = xsdbool( iv_doc_date <= iv_today ).
  ENDMETHOD.

  METHOD is_posting_date_valid.
    " Financial subledger constraint: Posting date cannot precede the baseline document date
    rv_is_valid = xsdbool( iv_post_date >= iv_doc_date ).
  ENDMETHOD.

  METHOD is_delivery_date_valid.
    " Supply Chain constraint: Goods cannot be requested for delivery before the order exists
    rv_is_valid = xsdbool( iv_del_date >= iv_doc_date ).
  ENDMETHOD.

  METHOD is_pur_partner_supplier.
    " Checks if the master data record flag for supplier is active
    rv_is_valid = xsdbool( iv_is_supplier = abap_true ).
  ENDMETHOD.

  METHOD is_sd_partner_customer.
    " Checks if the master data record flag for customer is active
    rv_is_valid = xsdbool( iv_is_customer = abap_true ).
  ENDMETHOD.

  METHOD is_item_quantity_valid.
    " Purchasing rule: Order line items must require a positive volume/quantity
    rv_is_valid = xsdbool( iv_quantity > 0 ).
  ENDMETHOD.

  METHOD is_item_price_valid.
    " Commercial constraint: Unit pricing must hold a real positive value
    rv_is_valid = xsdbool( iv_price > 0 ).
  ENDMETHOD.

  METHOD get_duplicate_item_codes.
    CLEAR rt_duplicates.

    DATA lt_processed TYPE SORTED TABLE OF ty_item_duplicate WITH UNIQUE KEY HeaderUUID ItemCode.

    LOOP AT it_items INTO DATA(ls_item).
      IF ls_item-HeaderUUID IS INITIAL OR ls_item-ItemCode IS INITIAL.
        CONTINUE.
      ENDIF.

      " Try inserting into processed table; sy-subrc <> 0 means it's a duplicate
      INSERT VALUE #( HeaderUUID = ls_item-HeaderUUID ItemCode = ls_item-ItemCode )
             INTO TABLE lt_processed.

      IF sy-subrc <> 0.
        " Insert into hashed table; unique key automatically prevents duplicate results for 3+ occurrences
        INSERT VALUE #( HeaderUUID = ls_item-HeaderUUID ItemCode = ls_item-ItemCode )
               INTO TABLE rt_duplicates.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


ENDCLASS.

