"! Shared business logic of a document whose items reference the items of an order
"! (Goods Receipt -> Purchase Order, Goods Issue -> Sales Order): open quantities and amounts, order progress.
"! Pure business logic without RAP dependencies (as ZCL_MERP_DOC_ITEM_LOGIC): the caller maps the progress
"! rows of its order selector to TY_ORDER_ITEM, its items to ZCL_MERP_DOC_ITEM_LOGIC=>TY_ITEM
"! (order item reference in OrderItemReferenceUUID) and the results back to its own messages and fields.
CLASS zcl_merp_doc_order_ref_logic DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Result of the check of a follow-up item against the open values of its order item
    CONSTANTS: BEGIN OF c_open_check,
                 item_not_found    TYPE c LENGTH 1 VALUE 'N',
                 quantity_exceeded TYPE c LENGTH 1 VALUE 'Q',
                 amounts_changed   TYPE c LENGTH 1 VALUE 'A',
               END OF c_open_check.

    "! Progress of an order item from the posted follow-up documents. The caller fills it from the progress
    "! view of its order with CORRESPONDING ... MAPPING (OrderUUID = PoHeaderUUID, OrderItemUUID = PoItemUUID,
    "! DoneQuantity = ReceivedQuantity; sales order: So... fields, DoneQuantity = IssuedQuantity).
    TYPES: BEGIN OF ty_order_item,
             OrderUUID       TYPE sysuuid_x16,
             OrderItemUUID   TYPE sysuuid_x16,
             OrderedQuantity TYPE zmerp_quantity,
             DoneQuantity    TYPE zmerp_quantity,
             OpenQuantity    TYPE zmerp_quantity,
             OpenNetAmount   TYPE zmerp_net_amount,
             OpenVatAmount   TYPE zmerp_vat_amount,
             OpenGrossAmount TYPE zmerp_gross_amount,
           END OF ty_order_item,
           tt_order_items TYPE SORTED TABLE OF ty_order_item WITH UNIQUE KEY OrderItemUUID.

    "! Follow-up item that does not fit the open values of its order item (see C_OPEN_CHECK)
    TYPES: BEGIN OF ty_open_check,
             ItemUUID     TYPE sysuuid_x16,
             Result       TYPE c LENGTH 1,
             OpenQuantity TYPE zmerp_quantity,
           END OF ty_open_check,
           tt_open_checks TYPE STANDARD TABLE OF ty_open_check WITH EMPTY KEY.

    "! Progress of an order after posting / unposting follow-up items
    TYPES: BEGIN OF ty_order_progress,
             OrderUUID TYPE sysuuid_x16,
             AnyDone   TYPE abap_bool,
             AllDone   TYPE abap_bool,
           END OF ty_order_progress,
           tt_order_progress TYPE STANDARD TABLE OF ty_order_progress WITH EMPTY KEY.

    "! Quantity or price changed: an item that takes the whole open quantity of its order item takes its
    "! open amounts, so the order item is closed to zero (earlier rounding differences included)
    "! @parameter it_items       | Changed items (ItemUUID, IsDraft, Quantity, Price, VatCode, amounts, OrderItemReferenceUUID)
    "! @parameter it_order_items | Open values of the referenced order items
    "! @parameter et_changed     | Items whose amounts changed to the open amounts (with the new amounts)
    "! @parameter et_calc        | Items for the standard calculation (partial quantity, manual items, unknown order item)
    CLASS-METHODS apply_open_amounts
      IMPORTING it_items       TYPE zcl_merp_doc_item_logic=>tt_items
                it_order_items TYPE tt_order_items
      EXPORTING et_changed     TYPE zcl_merp_doc_item_logic=>tt_items
                et_calc        TYPE zcl_merp_doc_item_logic=>tt_items.

    "! Checks items with an order reference against the open values of their order items:
    "! the order item exists, quantity <= open quantity, the whole open quantity takes exactly the open amounts
    "! @parameter it_items       | Items of one document (ItemUUID, Quantity, amounts, OrderItemReferenceUUID)
    "! @parameter it_order_items | Open values of the order items
    "! @parameter rt_checks      | Only the items that fail, with the first failing rule
    CLASS-METHODS check_open_values
      IMPORTING it_items         TYPE zcl_merp_doc_item_logic=>tt_items
                it_order_items   TYPE tt_order_items
      RETURNING VALUE(rt_checks) TYPE tt_open_checks.

    "! An accepted document takes its part of the open values, so further documents of the same request
    "! on the same order are checked against the rest
    "! @parameter it_items       | Items of the accepted document (Quantity, amounts, OrderItemReferenceUUID)
    "! @parameter ct_order_items | Open values of the order items, reduced by the items
    CLASS-METHODS consume_open_values
      IMPORTING it_items       TYPE zcl_merp_doc_item_logic=>tt_items
      CHANGING  ct_order_items TYPE tt_order_items.

    "! Progress of the orders after the given items are posted (iv_sign = 1) or unposted (iv_sign = -1).
    "! Only orders touched by the items are returned.
    "! @parameter it_items       | Follow-up items (OrderItemReferenceUUID, Quantity)
    "! @parameter it_order_items | Progress of the order items (posted follow-up documents only)
    "! @parameter iv_sign        | 1 = items are added to the done quantity, -1 = removed
    "! @parameter rt_progress    | Per touched order: something done / everything done
    CLASS-METHODS calc_order_progress
      IMPORTING it_items           TYPE zcl_merp_doc_item_logic=>tt_items
                it_order_items     TYPE tt_order_items
                iv_sign            TYPE i
      RETURNING VALUE(rt_progress) TYPE tt_order_progress.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_merp_doc_order_ref_logic IMPLEMENTATION.

  METHOD apply_open_amounts.
    CLEAR: et_changed, et_calc.

    LOOP AT it_items INTO DATA(ls_item).
      ASSIGN it_order_items[ OrderItemUUID = ls_item-OrderItemReferenceUUID ] TO FIELD-SYMBOL(<ls_open>).

      IF sy-subrc = 0 AND ls_item-Quantity = <ls_open>-OpenQuantity.
        " The whole open quantity takes the open amounts (only items whose amounts really change)
        IF ls_item-NetAmount   <> <ls_open>-OpenNetAmount OR
           ls_item-VatAmount   <> <ls_open>-OpenVatAmount OR
           ls_item-GrossAmount <> <ls_open>-OpenGrossAmount.
          ls_item-NetAmount   = <ls_open>-OpenNetAmount.
          ls_item-VatAmount   = <ls_open>-OpenVatAmount.
          ls_item-GrossAmount = <ls_open>-OpenGrossAmount.
          APPEND ls_item TO et_changed.
        ENDIF.
      ELSE.
        " Partial quantity and items without order reference: standard calculation
        APPEND ls_item TO et_calc.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD check_open_values.
    " Manually added items have no order reference and are not checked
    LOOP AT it_items INTO DATA(ls_item) WHERE OrderItemReferenceUUID IS NOT INITIAL.
      ASSIGN it_order_items[ OrderItemUUID = ls_item-OrderItemReferenceUUID ] TO FIELD-SYMBOL(<ls_open>).

      IF sy-subrc <> 0.
        " The referenced order item does not exist (any more)
        APPEND VALUE #( ItemUUID = ls_item-ItemUUID
                        Result   = c_open_check-item_not_found ) TO rt_checks.
      ELSEIF ls_item-Quantity > <ls_open>-OpenQuantity.
        APPEND VALUE #( ItemUUID     = ls_item-ItemUUID
                        Result       = c_open_check-quantity_exceeded
                        OpenQuantity = <ls_open>-OpenQuantity ) TO rt_checks.
      ELSEIF ls_item-Quantity = <ls_open>-OpenQuantity
         AND ( ls_item-NetAmount   <> <ls_open>-OpenNetAmount
            OR ls_item-VatAmount   <> <ls_open>-OpenVatAmount
            OR ls_item-GrossAmount <> <ls_open>-OpenGrossAmount ).
        " The whole open quantity must take exactly the open amounts, so the order item is closed to zero
        APPEND VALUE #( ItemUUID     = ls_item-ItemUUID
                        Result       = c_open_check-amounts_changed
                        OpenQuantity = <ls_open>-OpenQuantity ) TO rt_checks.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD consume_open_values.
    LOOP AT it_items INTO DATA(ls_item) WHERE OrderItemReferenceUUID IS NOT INITIAL.
      ASSIGN ct_order_items[ OrderItemUUID = ls_item-OrderItemReferenceUUID ] TO FIELD-SYMBOL(<ls_open>).
      IF sy-subrc = 0.
        <ls_open>-OpenQuantity    -= ls_item-Quantity.
        <ls_open>-OpenNetAmount   -= ls_item-NetAmount.
        <ls_open>-OpenVatAmount   -= ls_item-VatAmount.
        <ls_open>-OpenGrossAmount -= ls_item-GrossAmount.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD calc_order_progress.
    LOOP AT it_order_items INTO DATA(ls_order_item)
         GROUP BY ls_order_item-OrderUUID
         INTO DATA(lv_order_uuid).

      DATA(lv_touched)  = abap_false.
      DATA(lv_any_done) = abap_false.
      DATA(lv_all_done) = abap_true.

      LOOP AT GROUP lv_order_uuid INTO DATA(ls_item).
        " Quantity of the given follow-up items for this order item
        DATA(lv_delta) = REDUCE zmerp_quantity( INIT sum TYPE zmerp_quantity
                                                FOR item IN it_items
                                                WHERE ( OrderItemReferenceUUID = ls_item-OrderItemUUID )
                                                NEXT sum = sum + item-Quantity ).
        IF lv_delta <> 0.
          lv_touched = abap_true.
        ENDIF.

        " Done quantity after posting / unposting the given items
        DATA(lv_done) = ls_item-DoneQuantity + iv_sign * lv_delta.

        IF lv_done > 0.
          lv_any_done = abap_true.
        ENDIF.
        IF lv_done < ls_item-OrderedQuantity.
          lv_all_done = abap_false.
        ENDIF.
      ENDLOOP.

      " Orders not touched by the given items keep their status
      IF lv_touched = abap_true.
        APPEND VALUE #( OrderUUID = lv_order_uuid
                        AnyDone   = lv_any_done
                        AllDone   = lv_all_done ) TO rt_progress.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
