"! Purchase Order lifecycle rules (status model and allowed operations).
"! Pure business logic without RAP dependencies.
CLASS zcl_merp_doc_po_lifecycle DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CONSTANTS:
      " Purchase order lifecycle statuses
      c_status_new         TYPE zmerp_po_status VALUE 'N',
      c_status_approved    TYPE zmerp_po_status VALUE 'A',
      c_status_in_delivery TYPE zmerp_po_status VALUE 'P',
      c_status_completed   TYPE zmerp_po_status VALUE 'C',
      c_status_cancelled   TYPE zmerp_po_status VALUE 'X'.

    "! Only documents in 'New' status can be edited
    CLASS-METHODS can_edit
      IMPORTING iv_status         TYPE zmerp_po_status
      RETURNING VALUE(rv_allowed) TYPE abap_bool.

    "! Only documents in 'New' status can be released
    CLASS-METHODS can_release
      IMPORTING iv_status         TYPE zmerp_po_status
      RETURNING VALUE(rv_allowed) TYPE abap_bool.

    "! 'New', 'Approved' and 'In Delivery' documents can be cancelled by status;
    "! an 'In Delivery' document additionally must not have posted goods receipts (checked by the caller)
    CLASS-METHODS can_cancel
      IMPORTING iv_status         TYPE zmerp_po_status
      RETURNING VALUE(rv_allowed) TYPE abap_bool.

    "! Deletion is allowed only for 'New' or 'Cancelled' documents
    CLASS-METHODS can_delete
      IMPORTING iv_status         TYPE zmerp_po_status
      RETURNING VALUE(rv_allowed) TYPE abap_bool.

    "! Only 'Approved' documents can be moved to delivery
    CLASS-METHODS can_set_in_delivery
      IMPORTING iv_status         TYPE zmerp_po_status
      RETURNING VALUE(rv_allowed) TYPE abap_bool.

    "! Goods receipt is possible for 'Approved' and 'In Delivery' documents
    CLASS-METHODS can_receive_goods
      IMPORTING iv_status         TYPE zmerp_po_status
      RETURNING VALUE(rv_allowed) TYPE abap_bool.

    "! 'Approved' and 'In Delivery' documents can be completed manually (also with open quantities)
    CLASS-METHODS can_complete
      IMPORTING iv_status         TYPE zmerp_po_status
      RETURNING VALUE(rv_allowed) TYPE abap_bool.

    "! Delivery date must not be in the past while the document is in 'New' status
    "! @parameter iv_status        | Current document status
    "! @parameter iv_delivery_date | Delivery date to be checked
    "! @parameter iv_today         | Current system date context
    "! @parameter rv_is_valid      | Returns abap_true if the delivery date is acceptable for the status
    CLASS-METHODS is_delivery_date_actual
      IMPORTING iv_status         TYPE zmerp_po_status
                iv_delivery_date  TYPE zmerp_delivery_date
                iv_today          TYPE d
      RETURNING VALUE(rv_is_valid) TYPE abap_bool.

        "! Statuses driven by the goods receipt progress: Approved, In Delivery, Completed
    CLASS-METHODS is_receipt_status
      IMPORTING iv_status        TYPE zmerp_po_status
      RETURNING VALUE(rv_result) TYPE abap_bool.

    "! Status derived from the goods receipt progress: nothing received -> Approved,
    "! partly received -> In Delivery, everything received -> Completed.
    "! Statuses outside the receipt lifecycle (New, Cancelled) are returned unchanged.
    "! @parameter iv_status       | Current document status
    "! @parameter iv_any_received | At least one item has a received quantity
    "! @parameter iv_all_received | All items are received completely
    "! @parameter rv_status       | Derived document status
    CLASS-METHODS derive_receipt_status
      IMPORTING iv_status        TYPE zmerp_po_status
                iv_any_received  TYPE abap_bool
                iv_all_received  TYPE abap_bool
      RETURNING VALUE(rv_status) TYPE zmerp_po_status.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_merp_doc_po_lifecycle IMPLEMENTATION.

  METHOD can_edit.
    rv_allowed = xsdbool( iv_status = c_status_new ).
  ENDMETHOD.

  METHOD can_release.
    rv_allowed = xsdbool( iv_status = c_status_new ).
  ENDMETHOD.

  METHOD can_cancel.
    rv_allowed = xsdbool( iv_status = c_status_new
                       OR iv_status = c_status_approved
                       OR iv_status = c_status_in_delivery ).
  ENDMETHOD.

  METHOD can_delete.
    rv_allowed = xsdbool( iv_status = c_status_new OR iv_status = c_status_cancelled ).
  ENDMETHOD.

  METHOD can_set_in_delivery.
    rv_allowed = xsdbool( iv_status = c_status_approved ).
  ENDMETHOD.

  METHOD can_receive_goods.
    rv_allowed = xsdbool( iv_status = c_status_approved OR iv_status = c_status_in_delivery ).
  ENDMETHOD.

  METHOD can_complete.
    rv_allowed = xsdbool( iv_status = c_status_approved OR iv_status = c_status_in_delivery ).
  ENDMETHOD.

  METHOD is_receipt_status.
    rv_result = xsdbool( iv_status = c_status_approved
                      OR iv_status = c_status_in_delivery
                      OR iv_status = c_status_completed ).
  ENDMETHOD.

  METHOD derive_receipt_status.
    IF is_receipt_status( iv_status ) = abap_false.
      rv_status = iv_status.
      RETURN.
    ENDIF.

    rv_status = COND #( WHEN iv_all_received = abap_true THEN c_status_completed
                        WHEN iv_any_received = abap_true THEN c_status_in_delivery
                        ELSE c_status_approved ).
  ENDMETHOD.

  METHOD is_delivery_date_actual.
    " Past delivery date check holds only during the New status creation phase
    rv_is_valid = xsdbool( iv_status <> c_status_new OR iv_delivery_date >= iv_today ).
  ENDMETHOD.

ENDCLASS.
