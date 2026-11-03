"! Goods Receipt lifecycle rules (status model and allowed operations).
"! Pure business logic without RAP dependencies.
CLASS zcl_merp_doc_gr_lifecycle DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    TYPES tt_status TYPE STANDARD TABLE OF zmerp_gr_status WITH EMPTY KEY.

    CONSTANTS:
      " Goods Receipt lifecycle statuses
      c_status_new       TYPE zmerp_gr_status VALUE 'N',
      c_status_posted    TYPE zmerp_gr_status VALUE 'P',
      c_status_cancelled TYPE zmerp_gr_status VALUE 'X'.

    "! Returns a list of all statuses that are considered posted and affect inventory
    CLASS-METHODS get_posted_statuses
      RETURNING VALUE(rt_statuses) TYPE tt_status.

    "! Only documents in 'New' status can be edited
    CLASS-METHODS can_edit
      IMPORTING iv_status         TYPE zmerp_gr_status
      RETURNING VALUE(rv_allowed) TYPE abap_bool.

    "! Only documents in 'New' status can be posted
    CLASS-METHODS can_post
      IMPORTING iv_status         TYPE zmerp_gr_status
      RETURNING VALUE(rv_allowed) TYPE abap_bool.

    "! Only 'New' documents can be cancelled (posted documents are unposted first)
    CLASS-METHODS can_cancel
      IMPORTING iv_status         TYPE zmerp_gr_status
      RETURNING VALUE(rv_allowed) TYPE abap_bool.

    "! Only 'Posted' documents can be unposted (back to 'New')
    CLASS-METHODS can_unpost
      IMPORTING iv_status         TYPE zmerp_gr_status
      RETURNING VALUE(rv_allowed) TYPE abap_bool.

    "! Deletion is allowed only for 'New' or 'Cancelled' documents
    CLASS-METHODS can_delete
      IMPORTING iv_status         TYPE zmerp_gr_status
      RETURNING VALUE(rv_allowed) TYPE abap_bool.

    "! Checks if the document is posted and actively increases stock inventory
    CLASS-METHODS is_posted
      IMPORTING iv_status         TYPE zmerp_gr_status
      RETURNING VALUE(rv_allowed) TYPE abap_bool.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_merp_doc_gr_lifecycle IMPLEMENTATION.

  METHOD get_posted_statuses.
    rt_statuses = VALUE #(
      ( c_status_posted )
      " Add any future posted or stock-relevant statuses here centrally
    ).
  ENDMETHOD.

  METHOD can_edit.
    rv_allowed = xsdbool( iv_status = c_status_new ).
  ENDMETHOD.

  METHOD can_post.
    rv_allowed = xsdbool( iv_status = c_status_new ).
  ENDMETHOD.

  METHOD can_cancel.
    rv_allowed = xsdbool( iv_status = c_status_new ).
  ENDMETHOD.

  METHOD can_unpost.
    rv_allowed = xsdbool( iv_status = c_status_posted ).
  ENDMETHOD.

  METHOD can_delete.
    rv_allowed = xsdbool( iv_status = c_status_new OR iv_status = c_status_cancelled ).
  ENDMETHOD.

  METHOD is_posted.
    DATA(lt_posted_statuses) = get_posted_statuses( ).
    rv_allowed = xsdbool( line_exists( lt_posted_statuses[ table_line = iv_status ] ) ).
  ENDMETHOD.

ENDCLASS.
