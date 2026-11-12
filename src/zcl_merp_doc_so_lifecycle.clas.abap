"! Sales Order lifecycle rules (status model and allowed operations).
"! Pure business logic without RAP dependencies.
CLASS zcl_merp_doc_so_lifecycle DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CONSTANTS:
      " Sales order lifecycle statuses (overall status of a sales order, as in SAP SD)
      c_status_open       TYPE zmerp_so_status VALUE 'N',
      c_status_in_process TYPE zmerp_so_status VALUE 'P',
      c_status_completed  TYPE zmerp_so_status VALUE 'C',
      c_status_rejected   TYPE zmerp_so_status VALUE 'X'.

    "! Only 'Open' documents can be edited (an 'In Process' document has posted goods issues)
    CLASS-METHODS can_edit
      IMPORTING iv_status         TYPE zmerp_so_status
      RETURNING VALUE(rv_allowed) TYPE abap_bool.

    "! Only 'Open' documents can be rejected: an 'In Process' document has posted goods issues
    CLASS-METHODS can_reject
      IMPORTING iv_status         TYPE zmerp_so_status
      RETURNING VALUE(rv_allowed) TYPE abap_bool.

    "! Deletion is allowed only for 'Open' or 'Rejected' documents
    CLASS-METHODS can_delete
      IMPORTING iv_status         TYPE zmerp_so_status
      RETURNING VALUE(rv_allowed) TYPE abap_bool.

    "! Goods issue is possible for 'Open' and 'In Process' documents
    CLASS-METHODS can_issue_goods
      IMPORTING iv_status         TYPE zmerp_so_status
      RETURNING VALUE(rv_allowed) TYPE abap_bool.

    "! 'In Process' documents can be completed manually (the open quantities are not issued any more)
    CLASS-METHODS can_complete
      IMPORTING iv_status         TYPE zmerp_so_status
      RETURNING VALUE(rv_allowed) TYPE abap_bool.

    "! Statuses driven by the goods issue progress: Open, In Process, Completed
    CLASS-METHODS is_issue_status
      IMPORTING iv_status        TYPE zmerp_so_status
      RETURNING VALUE(rv_result) TYPE abap_bool.

    "! Status derived from the goods issue progress: nothing issued -> Open,
    "! partly issued -> In Process, everything issued -> Completed.
    "! Statuses outside the issue lifecycle (Rejected) are returned unchanged.
    "! @parameter iv_status     | Current document status
    "! @parameter iv_any_issued | At least one item has an issued quantity
    "! @parameter iv_all_issued | All items are issued completely
    "! @parameter rv_status     | Derived document status
    CLASS-METHODS derive_issue_status
      IMPORTING iv_status        TYPE zmerp_so_status
                iv_any_issued    TYPE abap_bool
                iv_all_issued    TYPE abap_bool
      RETURNING VALUE(rv_status) TYPE zmerp_so_status.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_merp_doc_so_lifecycle IMPLEMENTATION.

  METHOD can_edit.
    rv_allowed = xsdbool( iv_status = c_status_open ).
  ENDMETHOD.

  METHOD can_reject.
    rv_allowed = xsdbool( iv_status = c_status_open ).
  ENDMETHOD.

  METHOD can_delete.
    rv_allowed = xsdbool( iv_status = c_status_open OR iv_status = c_status_rejected ).
  ENDMETHOD.

  METHOD can_issue_goods.
    rv_allowed = xsdbool( iv_status = c_status_open OR iv_status = c_status_in_process ).
  ENDMETHOD.

  METHOD can_complete.
    rv_allowed = xsdbool( iv_status = c_status_in_process ).
  ENDMETHOD.

  METHOD is_issue_status.
    rv_result = xsdbool( iv_status = c_status_open
                      OR iv_status = c_status_in_process
                      OR iv_status = c_status_completed ).
  ENDMETHOD.

  METHOD derive_issue_status.
    IF is_issue_status( iv_status ) = abap_false.
      rv_status = iv_status.
      RETURN.
    ENDIF.

    rv_status = COND #( WHEN iv_all_issued = abap_true THEN c_status_completed
                        WHEN iv_any_issued = abap_true THEN c_status_in_process
                        ELSE c_status_open ).
  ENDMETHOD.

ENDCLASS.
