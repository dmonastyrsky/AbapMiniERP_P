"! Writes the stock movement journal ZMERP_STOCK_MOV (GR28, GR33).
"! Writes to the database: call only from the save phase of a business object
"! (save_modified of an additional save), never from determinations, validations or actions.
"! Both methods work on sets: one database operation for all documents of a request.
CLASS zcl_merp_stock_posting DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_document_key,
             document_uuid TYPE zmerp_stock_mov-document_uuid,
           END OF ty_document_key,
           tt_document_keys TYPE STANDARD TABLE OF ty_document_key WITH EMPTY KEY.

    "! One movement of a document line. Receipts have a positive quantity and value,
    "! issues a negative one; the value is in company currency.
    TYPES: BEGIN OF ty_movement,
             document_uuid      TYPE zmerp_stock_mov-document_uuid,
             document_item_uuid TYPE zmerp_stock_mov-document_item_uuid,
             company_code       TYPE zmerp_stock_mov-company_code,
             warehouse_code     TYPE zmerp_stock_mov-warehouse_code,
             item_code          TYPE zmerp_stock_mov-item_code,
             quantity           TYPE zmerp_stock_mov-quantity,
             unit_of_measure    TYPE zmerp_stock_mov-unit_of_measure,
             amount             TYPE zmerp_stock_mov-amount,
             currency_code      TYPE zmerp_stock_mov-currency_code,
             posting_date       TYPE zmerp_stock_mov-posting_date,
           END OF ty_movement,
           tt_movements TYPE STANDARD TABLE OF ty_movement WITH EMPTY KEY.

    "! Removes all movements of the given documents (documents without movements are ignored).
    "! @parameter it_document_keys | Documents whose movements are removed
    CLASS-METHODS delete_document_movements
      IMPORTING
        it_document_keys TYPE tt_document_keys.

    "! Inserts the movements of document lines. Services (item type S) are not kept in stock
    "! and are skipped (GR31).
    "! @parameter iv_document_type | Document type of the movements ('GR', later 'GI')
    "! @parameter it_movements     | Movements of the document lines (one or several documents)
    CLASS-METHODS insert_movements
      IMPORTING
        iv_document_type TYPE zmerp_doc_type
        it_movements     TYPE tt_movements.

ENDCLASS.



CLASS zcl_merp_stock_posting IMPLEMENTATION.

  METHOD delete_document_movements.
    IF it_document_keys IS INITIAL.
      RETURN.
    ENDIF.

    " One read and one delete (by primary key) for all documents
    SELECT mov~*
      FROM zmerp_stock_mov AS mov
      INNER JOIN @it_document_keys AS doc ON mov~document_uuid = doc~document_uuid
      INTO TABLE @DATA(lt_db_movements).

    IF lt_db_movements IS NOT INITIAL.
      DELETE zmerp_stock_mov FROM TABLE @lt_db_movements.
    ENDIF.
  ENDMETHOD.

  METHOD insert_movements.
    DATA lt_db_movements TYPE STANDARD TABLE OF zmerp_stock_mov WITH EMPTY KEY.

    IF it_movements IS INITIAL.
      RETURN.
    ENDIF.

    " Services are received (order progress) but are not kept in stock
    DATA(lt_items_master) = NEW zcl_merp_md_item_sel( )->zif_merp_md_item_sel~read_items(
      VALUE #( FOR movement IN it_movements ( ItemCode = movement-item_code ) ) ).

    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD DATA(lv_timestamp).

    LOOP AT it_movements REFERENCE INTO DATA(lr_movement).
      IF VALUE #( lt_items_master[ ItemCode = lr_movement->item_code ]-ItemTypeCode OPTIONAL )
         = zif_merp_constants=>c_item_type-service.
        CONTINUE.
      ENDIF.

      TRY.
          APPEND VALUE #(
            movement_uuid         = cl_system_uuid=>create_uuid_x16_static( )
            company_code          = lr_movement->company_code
            warehouse_code        = lr_movement->warehouse_code
            item_code             = lr_movement->item_code
            quantity              = lr_movement->quantity
            unit_of_measure       = lr_movement->unit_of_measure
            amount                = lr_movement->amount
            currency_code         = lr_movement->currency_code
            posting_date          = lr_movement->posting_date
            document_type         = iv_document_type
            document_uuid         = lr_movement->document_uuid
            document_item_uuid    = lr_movement->document_item_uuid
            created_by            = lv_user
            created_at            = lv_timestamp
            local_last_changed_by = lv_user
            local_last_changed_at = lv_timestamp
            last_changed_at       = lv_timestamp
          ) TO lt_db_movements.
        CATCH cx_uuid_error INTO DATA(lx_uuid).
          " A posted document without its stock movement would break the stock:
          " abort the save (the whole transaction is rolled back) instead of skipping the movement
          RAISE SHORTDUMP lx_uuid.
      ENDTRY.
    ENDLOOP.

    IF lt_db_movements IS NOT INITIAL.
      INSERT zmerp_stock_mov FROM TABLE @lt_db_movements.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
