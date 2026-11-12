"! Shared business logic for document items (Purchase Order, Goods Receipt, ...).
"! Pure business logic without RAP dependencies: works on plain item tables, the caller
"! (behavior handler) is responsible for reading from and writing to the transactional buffer.
CLASS zcl_merp_doc_item_logic DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Step between two item numbers within a document
    CONSTANTS c_item_no_step TYPE i VALUE 10.

    "! Item data in the shape of the common item structure ZMERP_S_DOC_ITM_COMMON.
    "! Component names match the fields of the document item entities, so the caller can fill it with
    "! CORRESPONDING (IsDraft is the only technical field: pass-through of %is_draft, needed to map results back).
    "! Only the fields read by the caller are filled, all other components stay initial.
    "! OrderItemReferenceUUID: reference to the order item (PO item for a goods receipt, SO item for a goods issue);
    "! filled by the caller from its own reference field, lines with a reference keep the values of the order.
    TYPES: BEGIN OF ty_item,
             ItemUUID            TYPE sysuuid_x16,
             HeaderUUID          TYPE sysuuid_x16,
             IsDraft             TYPE abp_behv_flag,
             ItemNo              TYPE zmerp_item_no,
             ItemCode            TYPE zmerp_item_code,
             Quantity            TYPE zmerp_quantity,
             UnitOfMeasure       TYPE zmerp_unit,
             CurrencyCode        TYPE zmerp_currency_code,
             Price               TYPE zmerp_price,
             NetAmount           TYPE zmerp_net_amount,
             VatCode             TYPE zmerp_vat_code,
             VatAmount           TYPE zmerp_vat_amount,
             GrossAmount         TYPE zmerp_gross_amount,
             OrderItemReferenceUUID TYPE sysuuid_x16,
           END OF ty_item,
           tt_items TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.

    "! Document key: header UUID + draft state (the same UUID can exist as active and as draft instance)
    TYPES: BEGIN OF ty_header_key,
             HeaderUUID TYPE sysuuid_x16,
             IsDraft    TYPE abp_behv_flag,
           END OF ty_header_key,
           tt_header_keys TYPE STANDARD TABLE OF ty_header_key WITH EMPTY KEY.

    "! Currency of a document header
    TYPES: BEGIN OF ty_header_currency,
             HeaderUUID   TYPE sysuuid_x16,
             IsDraft      TYPE abp_behv_flag,
             CurrencyCode TYPE zmerp_currency_code,
           END OF ty_header_currency,
           tt_header_currencies TYPE STANDARD TABLE OF ty_header_currency WITH EMPTY KEY.

    "! Calculated totals of a document header
    TYPES: BEGIN OF ty_header_totals,
             HeaderUUID       TYPE sysuuid_x16,
             IsDraft          TYPE abp_behv_flag,
             TotalNetAmount   TYPE zmerp_net_amount,
             TotalGrossAmount TYPE zmerp_gross_amount,
           END OF ty_header_totals,
           tt_header_totals TYPE STANDARD TABLE OF ty_header_totals WITH EMPTY KEY.

    "! @parameter io_vat_selector  | VAT rate selector; if not supplied, the standard selector is used (inject a test double in unit tests)
    "! @parameter io_item_selector | Item master data selector; if not supplied, the standard selector is used
    METHODS constructor
      IMPORTING io_vat_selector  TYPE REF TO zif_merp_md_vat_rate_sel OPTIONAL
                io_item_selector TYPE REF TO zif_merp_md_item_sel OPTIONAL.

    "! Quantity or price changed: net -> VAT -> gross are recalculated (prices are always without VAT)
    "! @parameter it_items             | Items to be processed (HeaderUUID, ItemNo, ItemCode, UnitOfMeasure, VatCode, CurrencyCode, OrderItemReferenceUUID)
    "! @parameter rt_changed | Only the items whose amounts really changed (with the new amounts)
    METHODS recalc_on_qty_price
      IMPORTING it_items          TYPE tt_items
      RETURNING VALUE(rt_changed) TYPE tt_items.

    "! VAT code changed: net amount stays, VAT and gross amounts are recalculated
    "! @parameter it_items   | Items with VatCode, NetAmount, VatAmount and GrossAmount
    "! @parameter rt_changed | Only the items whose VAT or gross amount really changed (with the new amounts)
    METHODS recalc_on_vat_code
      IMPORTING it_items          TYPE tt_items
      RETURNING VALUE(rt_changed) TYPE tt_items.

    "! Derives item defaults: next item number, item currency from the header, UoM and VAT code from the item master data
    "! @parameter it_items             | Items to be processed (HeaderUUID, ItemNo, ItemCode, UnitOfMeasure, VatCode, CurrencyCode)
    "! @parameter it_siblings          | ALL items of the affected documents (HeaderUUID, ItemNo) to find the highest used item number
    "! @parameter it_header_currencies | Currencies of the parent documents
    "! @parameter rt_changed           | Only the items where at least one default was set (with the new values)
    METHODS set_defaults
      IMPORTING it_items             TYPE tt_items
                it_siblings          TYPE tt_items
                it_header_currencies TYPE tt_header_currencies
      RETURNING VALUE(rt_changed)    TYPE tt_items.

    "! Sums up item amounts into header totals
    "! @parameter it_header_keys | Documents to be recalculated (also documents that no longer have any items)
    "! @parameter it_items       | ALL items of these documents (HeaderUUID, IsDraft, NetAmount, VatAmount, GrossAmount)
    "! @parameter rt_totals      | Totals per document
    METHODS calc_header_totals
      IMPORTING it_header_keys    TYPE tt_header_keys
                it_items          TYPE tt_items
      RETURNING VALUE(rt_totals)  TYPE tt_header_totals.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mo_vat_selector  TYPE REF TO zif_merp_md_vat_rate_sel.
    DATA mo_item_selector TYPE REF TO zif_merp_md_item_sel.

    "! Returns the VAT percentage of a VAT code (0 if the VAT code is unknown)
    METHODS get_vat_percentage
      IMPORTING it_vat_rates         TYPE zif_merp_md_vat_rate_sel=>tt_vat_rates
                iv_vat_code          TYPE zmerp_vat_code
      RETURNING VALUE(rv_percentage) TYPE decfloat34.
ENDCLASS.


CLASS zcl_merp_doc_item_logic IMPLEMENTATION.

  METHOD constructor.
    IF io_vat_selector IS BOUND.
      mo_vat_selector = io_vat_selector.
    ELSE.
      mo_vat_selector = NEW zcl_merp_md_vat_rate_sel( ).
    ENDIF.

    IF io_item_selector IS BOUND.
      mo_item_selector = io_item_selector.
    ELSE.
      mo_item_selector = NEW zcl_merp_md_item_sel( ).
    ENDIF.
  ENDMETHOD.

  METHOD recalc_on_qty_price.
    IF it_items IS INITIAL.
      RETURN.
    ENDIF.

    " Bulk select VAT percentages (the selector cleanses keys itself: initial values and duplicates are ignored)
    DATA(lt_vat_rates) = mo_vat_selector->read_vat_rates(
      VALUE #( FOR item IN it_items ( VatCode = item-VatCode ) ) ).

    " Recalculate item amounts using pure business logic core
    LOOP AT it_items INTO DATA(ls_item).
      DATA(lv_percentage) = get_vat_percentage( it_vat_rates = lt_vat_rates
                                                iv_vat_code  = ls_item-VatCode ).

      " Quantity or price changed trigger event -> net -> VAT -> gross recalculation sequence
      DATA(ls_calculated_amounts) = zcl_merp_doc_calc=>calc_on_qty_price_change(
        iv_quantity       = ls_item-Quantity
        iv_price          = ls_item-Price
        iv_vat_percentage = lv_percentage
      ).

      " Return only items whose amounts really changed (avoids unnecessary modifications)
      IF ls_item-NetAmount   <> ls_calculated_amounts-net_amount   OR
         ls_item-VatAmount   <> ls_calculated_amounts-vat_amount   OR
         ls_item-GrossAmount <> ls_calculated_amounts-gross_amount.

        ls_item-NetAmount   = ls_calculated_amounts-net_amount.
        ls_item-VatAmount   = ls_calculated_amounts-vat_amount.
        ls_item-GrossAmount = ls_calculated_amounts-gross_amount.
        APPEND ls_item TO rt_changed.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD recalc_on_vat_code.
    IF it_items IS INITIAL.
      RETURN.
    ENDIF.

    " Bulk select VAT percentages (the selector cleanses keys itself: initial values and duplicates are ignored)
    DATA(lt_vat_rates) = mo_vat_selector->read_vat_rates(
      VALUE #( FOR item IN it_items ( VatCode = item-VatCode ) ) ).

    " Recalculate VAT and gross fields while the net amount stays unchanged
    LOOP AT it_items INTO DATA(ls_item).
      DATA(lv_percentage) = get_vat_percentage( it_vat_rates = lt_vat_rates
                                                iv_vat_code  = ls_item-VatCode ).

      " VAT rate changed trigger event -> VAT and gross calculation sequence
      DATA(ls_calculated_amounts) = zcl_merp_doc_calc=>calc_on_vat_rate_change(
        is_amounts        = VALUE #( net_amount   = ls_item-NetAmount
                                     vat_amount   = ls_item-VatAmount
                                     gross_amount = ls_item-GrossAmount )
        iv_vat_percentage = lv_percentage
      ).

      " Return only items whose amounts really changed (avoids unnecessary modifications)
      IF ls_item-VatAmount   <> ls_calculated_amounts-vat_amount OR
         ls_item-GrossAmount <> ls_calculated_amounts-gross_amount.

        ls_item-VatAmount   = ls_calculated_amounts-vat_amount.
        ls_item-GrossAmount = ls_calculated_amounts-gross_amount.
        APPEND ls_item TO rt_changed.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD set_defaults.
    TYPES: BEGIN OF ty_counter,
             header_uuid TYPE sysuuid_x16,
             last_no     TYPE i,
           END OF ty_counter.

    DATA lt_counters TYPE HASHED TABLE OF ty_counter WITH UNIQUE KEY header_uuid.

    IF it_items IS INITIAL.
      RETURN.
    ENDIF.

    " All items of the affected documents: highest used item number per document
    LOOP AT it_siblings REFERENCE INTO DATA(lr_sibling).
      ASSIGN lt_counters[ header_uuid = lr_sibling->HeaderUUID ] TO FIELD-SYMBOL(<ls_counter>).
      IF sy-subrc <> 0.
        INSERT VALUE #( header_uuid = lr_sibling->HeaderUUID )
          INTO TABLE lt_counters ASSIGNING <ls_counter>.
      ENDIF.

      IF lr_sibling->ItemNo > <ls_counter>-last_no.
        <ls_counter>-last_no = lr_sibling->ItemNo.
      ENDIF.
    ENDLOOP.

    " Item master data for all selected item codes in one selector call
    DATA(lt_items_master) = mo_item_selector->read_items(
      VALUE #( FOR item IN it_items ( ItemCode = item-ItemCode ) )
    ).

    " Default VAT codes of these items: a blocked (obsolete) VAT code is not proposed
    DATA(lt_vat_rates) = mo_vat_selector->read_vat_rates(
      VALUE #( FOR master IN lt_items_master ( VatCode = master-DefaultVatCode ) )
    ).

    LOOP AT it_items INTO DATA(ls_original).
      DATA(ls_item) = ls_original.

      " Next free item number within the document
      IF ls_item-ItemNo IS INITIAL.
        ASSIGN lt_counters[ header_uuid = ls_item-HeaderUUID ] TO <ls_counter>.
        IF sy-subrc = 0.
          <ls_counter>-last_no += c_item_no_step.
          ls_item-ItemNo     = <ls_counter>-last_no.
        ELSE.
          INSERT VALUE #( header_uuid = ls_item-HeaderUUID last_no = c_item_no_step )
            INTO TABLE lt_counters ASSIGNING <ls_counter>.
          ls_item-ItemNo = c_item_no_step.
        ENDIF.
      ENDIF.

      " Item currency follows the document currency (only if not yet set)
      IF ls_item-CurrencyCode IS INITIAL.
        ASSIGN it_header_currencies[ HeaderUUID = ls_item-HeaderUUID
                                     IsDraft    = ls_item-IsDraft ] TO FIELD-SYMBOL(<ls_header>).
        IF sy-subrc = 0.
          ls_item-CurrencyCode = <ls_header>-CurrencyCode.
        ENDIF.
      ENDIF.

      " UoM and VAT code are taken from the item master data (overwriting current values) if the item exists;
      " items copied from an order (purchase or sales order) keep the UoM and VAT code of the order item.
      " A blocked VAT code of the item is not proposed: the field is cleared, so the user selects a current one
      " (a VAT code of the previously selected item must not stay on the line)
      IF ls_item-ItemCode IS NOT INITIAL AND ls_item-OrderItemReferenceUUID IS INITIAL.
        ASSIGN lt_items_master[ ItemCode = ls_item-ItemCode ] TO FIELD-SYMBOL(<ls_master>).
        IF sy-subrc = 0.
          ls_item-UnitOfMeasure = <ls_master>-BaseUnitOfMeasure.
          ls_item-VatCode       = COND #( WHEN line_exists( lt_vat_rates[ VatCode   = <ls_master>-DefaultVatCode
                                                                          IsBlocked = abap_false ] )
                                          THEN <ls_master>-DefaultVatCode ).
        ENDIF.
      ENDIF.

      " Return only items that really changed
      IF ls_item <> ls_original.
        APPEND ls_item TO rt_changed.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD calc_header_totals.
    LOOP AT it_header_keys INTO DATA(ls_key).
      " Extract the exact item amount structures belonging to the current header document context (UUID + Draft status)
      DATA(lt_target_amounts) = VALUE zcl_merp_doc_calc=>tt_item_amounts(
        FOR item IN it_items WHERE ( HeaderUUID = ls_key-HeaderUUID
                                     AND IsDraft = ls_key-IsDraft )
        ( net_amount   = item-NetAmount
          vat_amount   = item-VatAmount
          gross_amount = item-GrossAmount )
      ).

      " Delegate execution to the pure business logic class that knows the calculation sequence
      DATA(ls_totals) = zcl_merp_doc_calc=>calculate_header_totals( lt_target_amounts ).

      APPEND VALUE #( HeaderUUID       = ls_key-HeaderUUID
                      IsDraft          = ls_key-IsDraft
                      TotalNetAmount   = ls_totals-total_net_amount
                      TotalGrossAmount = ls_totals-total_gross_amount ) TO rt_totals.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_vat_percentage.
    ASSIGN it_vat_rates[ VatCode = iv_vat_code ] TO FIELD-SYMBOL(<ls_vat>).
    IF sy-subrc = 0.
      rv_percentage = <ls_vat>-percentage.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

