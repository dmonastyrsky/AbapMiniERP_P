"! Stock control of document postings (interaction phase, before the save):
"! locks the stock of the posted products and checks that the stock does not become negative.
"! As in SAP, the stock is locked first and read afterwards, so two users cannot both take the last unit;
"! the locks are released at the end of the transaction (after the stock movements are saved).
"! Only items kept in stock are locked and checked (ZIF_MERP_MD_ITEM_SEL->read_stock_items, GR31).
"! Usage: lock_stock( keys ) -> NEW zcl_merp_stock_control( keys ) -> check_availability( ) per document.
CLASS zcl_merp_stock_control DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Document line that takes goods out of the stock (goods issue, unposting of a goods receipt)
    TYPES: BEGIN OF ty_line,
             item_uuid       TYPE sysuuid_x16,
             item_code       TYPE zmerp_item_code,
             quantity        TYPE zmerp_quantity,
             unit_of_measure TYPE zmerp_unit,
           END OF ty_line,
           tt_lines TYPE STANDARD TABLE OF ty_line WITH EMPTY KEY.

    "! Stock that could not be locked: another user is posting the same item in the same warehouse
    TYPES: BEGIN OF ty_lock_failure,
             company_code   TYPE zmerp_company_code,
             warehouse_code TYPE zmerp_warehouse_code,
             item_code      TYPE zmerp_item_code,
             locked_by      TYPE string,
           END OF ty_lock_failure,
           tt_lock_failures TYPE SORTED TABLE OF ty_lock_failure
                            WITH UNIQUE KEY company_code warehouse_code item_code.

    TYPES tt_item_uuids TYPE SORTED TABLE OF sysuuid_x16 WITH UNIQUE KEY table_line.

    "! Locks the stock of the given items (one lock per company, warehouse and item; the unit is not
    "! part of the lock, as for a material in SAP). Keys that are locked by another user are returned.
    "! @parameter it_stock_keys | Stock keys of the document lines (services and duplicates are ignored)
    "! @parameter rt_failures   | Keys locked by another user, with the user name
    CLASS-METHODS lock_stock
      IMPORTING it_stock_keys      TYPE zif_merp_stock_sel=>tt_stock_keys
      RETURNING VALUE(rt_failures) TYPE tt_lock_failures.

    "! Reads the current stock of the given keys; call it after lock_stock (lock first, then read).
    "! @parameter it_stock_keys | Stock keys of all documents to be checked
    METHODS constructor
      IMPORTING it_stock_keys TYPE zif_merp_stock_sel=>tt_stock_keys.

    "! Checks that the stock covers the lines of one document. Several lines of one item and several
    "! documents are checked one after another: a document without shortages takes its quantities
    "! from the stock, so the next document is checked against the rest.
    "! @parameter iv_company_code   | Company of the document
    "! @parameter iv_warehouse_code | Warehouse of the document
    "! @parameter it_lines          | Lines that take goods out of the stock (services are ignored)
    "! @parameter rt_shortages      | Lines without enough stock (empty = the document is covered)
    METHODS check_availability
      IMPORTING iv_company_code     TYPE zmerp_company_code
                iv_warehouse_code   TYPE zmerp_warehouse_code
                it_lines            TYPE tt_lines
      RETURNING VALUE(rt_shortages) TYPE tt_item_uuids.

  PRIVATE SECTION.
    CONSTANTS c_lock_object TYPE string VALUE 'EZMERP_STOCK'.

    "! Current stock, reduced by the documents accepted by check_availability
    DATA mt_stock TYPE zif_merp_stock_sel=>tt_balances.
ENDCLASS.


CLASS zcl_merp_stock_control IMPLEMENTATION.

  METHOD lock_stock.
    DATA lt_keys TYPE tt_lock_failures.

    DATA(lt_stock_items) = NEW zcl_merp_md_item_sel( )->zif_merp_md_item_sel~read_stock_items(
      VALUE #( FOR key IN it_stock_keys ( ItemCode = key-ItemCode ) ) ).

    " One lock per company, warehouse and item
    LOOP AT it_stock_keys INTO DATA(ls_stock_key).
      IF line_exists( lt_stock_items[ table_line = ls_stock_key-ItemCode ] ).
        INSERT VALUE #( company_code   = ls_stock_key-CompanyCode
                        warehouse_code = ls_stock_key-WarehouseCode
                        item_code      = ls_stock_key-ItemCode ) INTO TABLE lt_keys.
      ENDIF.
    ENDLOOP.

    IF lt_keys IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        DATA(lo_lock) = cl_abap_lock_object_factory=>get_instance( iv_name = CONV #( c_lock_object ) ).
      CATCH cx_abap_lock_failure INTO DATA(lx_instance).
        " A missing lock object is a system error: posting without a lock would allow negative stock
        RAISE SHORTDUMP lx_instance.
    ENDTRY.

    LOOP AT lt_keys INTO DATA(ls_key).
      TRY.
          " No waiting: the user gets the message at once and tries again (as in SAP)
          lo_lock->enqueue(
            it_parameter = VALUE #( ( name = 'COMPANY_CODE'   value = REF #( ls_key-company_code ) )
                                    ( name = 'WAREHOUSE_CODE' value = REF #( ls_key-warehouse_code ) )
                                    ( name = 'ITEM_CODE'      value = REF #( ls_key-item_code ) ) ) ).
        CATCH cx_abap_foreign_lock INTO DATA(lx_foreign).
          INSERT VALUE #( company_code   = ls_key-company_code
                          warehouse_code = ls_key-warehouse_code
                          item_code      = ls_key-item_code
                          locked_by      = lx_foreign->user_name ) INTO TABLE rt_failures.
        CATCH cx_abap_lock_failure INTO DATA(lx_failure).
          RAISE SHORTDUMP lx_failure.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.


  METHOD constructor.
    mt_stock = NEW zcl_merp_stock_sel( )->zif_merp_stock_sel~read_balances( it_stock_keys ).
  ENDMETHOD.


  METHOD check_availability.
    DATA(lt_stock_items) = NEW zcl_merp_md_item_sel( )->zif_merp_md_item_sel~read_stock_items(
      VALUE #( FOR line IN it_lines ( ItemCode = line-item_code ) ) ).

    " The document is checked against a copy: only a covered document reduces the stock
    DATA(lt_stock) = mt_stock.

    LOOP AT it_lines REFERENCE INTO DATA(lr_line) WHERE quantity > 0.
      IF NOT line_exists( lt_stock_items[ table_line = lr_line->item_code ] ).
        CONTINUE.
      ENDIF.

      ASSIGN lt_stock[ CompanyCode   = iv_company_code
                       WarehouseCode = iv_warehouse_code
                       ItemCode      = lr_line->item_code
                       UnitOfMeasure = lr_line->unit_of_measure ] TO FIELD-SYMBOL(<ls_stock>).

      IF sy-subrc <> 0 OR <ls_stock>-Quantity < lr_line->quantity.
        INSERT lr_line->item_uuid INTO TABLE rt_shortages.
      ELSE.
        <ls_stock>-Quantity -= lr_line->quantity.
      ENDIF.
    ENDLOOP.

    IF rt_shortages IS INITIAL.
      mt_stock = lt_stock.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
