"! Pure calculation logic for document items and headers (no RAP dependencies).
"! Each public method represents one change event and knows its own calculation sequence.
CLASS zcl_merp_doc_calc DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_item_amounts,
             net_amount   TYPE zmerp_net_amount,
             vat_amount   TYPE zmerp_vat_amount,
             gross_amount TYPE zmerp_gross_amount,
           END OF ty_item_amounts,
           tt_item_amounts TYPE STANDARD TABLE OF ty_item_amounts WITH EMPTY KEY.

    TYPES: BEGIN OF ty_header_totals,
             total_net_amount   TYPE zmerp_net_amount,
             total_gross_amount TYPE zmerp_gross_amount,
           END OF ty_header_totals.

    "! Quantity or price changed: net -> VAT -> gross (prices are always without VAT)
    "! @parameter iv_vat_percentage | VAT percentage (e.g. 19 for 19 %)
    "! @parameter rs_amounts        | Recalculated net, VAT and gross amount
    CLASS-METHODS calc_on_qty_price_change
      IMPORTING iv_quantity       TYPE zmerp_quantity
                iv_price          TYPE zmerp_price
                iv_vat_percentage TYPE decfloat34
      RETURNING VALUE(rs_amounts) TYPE ty_item_amounts.

    "! VAT rate changed: net amount stays, VAT -> gross are recalculated
    "! @parameter is_amounts | Current item amounts
    "! @parameter rs_amounts | Amounts with recalculated VAT and gross amount
    CLASS-METHODS calc_on_vat_rate_change
      IMPORTING is_amounts        TYPE ty_item_amounts
                iv_vat_percentage TYPE decfloat34
      RETURNING VALUE(rs_amounts) TYPE ty_item_amounts.

    "! VAT amount changed manually: only gross amount is recalculated
    "! @parameter is_amounts | Current item amounts (with the new VAT amount)
    "! @parameter rs_amounts | Amounts with recalculated gross amount
    CLASS-METHODS calc_on_vat_amount_change
      IMPORTING is_amounts        TYPE ty_item_amounts
      RETURNING VALUE(rs_amounts) TYPE ty_item_amounts.

    "! Sums up item amounts into document header totals
    CLASS-METHODS calculate_header_totals
      IMPORTING it_item_amounts  TYPE tt_item_amounts
      RETURNING VALUE(rs_totals) TYPE ty_header_totals.

  PRIVATE SECTION.
    CONSTANTS c_amount_decimals TYPE i VALUE 2.

    CLASS-METHODS net_amount
      IMPORTING iv_quantity          TYPE zmerp_quantity
                iv_price             TYPE zmerp_price
      RETURNING VALUE(rv_net_amount) TYPE zmerp_net_amount.

    CLASS-METHODS vat_amount
      IMPORTING iv_net_amount        TYPE zmerp_net_amount
                iv_vat_percentage    TYPE decfloat34
      RETURNING VALUE(rv_vat_amount) TYPE zmerp_vat_amount.

    CLASS-METHODS gross_amount
      IMPORTING iv_net_amount          TYPE zmerp_net_amount
                iv_vat_amount          TYPE zmerp_vat_amount
      RETURNING VALUE(rv_gross_amount) TYPE zmerp_gross_amount.
ENDCLASS.


CLASS zcl_merp_doc_calc IMPLEMENTATION.

  METHOD calc_on_qty_price_change.
    rs_amounts-net_amount   = net_amount( iv_quantity = iv_quantity
                                          iv_price    = iv_price ).
    rs_amounts-vat_amount   = vat_amount( iv_net_amount     = rs_amounts-net_amount
                                          iv_vat_percentage = iv_vat_percentage ).
    rs_amounts-gross_amount = gross_amount( iv_net_amount = rs_amounts-net_amount
                                            iv_vat_amount = rs_amounts-vat_amount ).
  ENDMETHOD.

  METHOD calc_on_vat_rate_change.
    rs_amounts              = is_amounts.
    rs_amounts-vat_amount   = vat_amount( iv_net_amount     = is_amounts-net_amount
                                          iv_vat_percentage = iv_vat_percentage ).
    rs_amounts-gross_amount = gross_amount( iv_net_amount = is_amounts-net_amount
                                            iv_vat_amount = rs_amounts-vat_amount ).
  ENDMETHOD.

  METHOD calc_on_vat_amount_change.
    rs_amounts              = is_amounts.
    rs_amounts-gross_amount = gross_amount( iv_net_amount = is_amounts-net_amount
                                            iv_vat_amount = is_amounts-vat_amount ).
  ENDMETHOD.

  METHOD calculate_header_totals.
    CLEAR rs_totals.
    LOOP AT it_item_amounts REFERENCE INTO DATA(lr_amounts).
      rs_totals-total_net_amount   += lr_amounts->net_amount.
      rs_totals-total_gross_amount += lr_amounts->gross_amount.
    ENDLOOP.
  ENDMETHOD.

  METHOD net_amount.
    rv_net_amount = round( val = iv_quantity * iv_price
                           dec = c_amount_decimals ).
  ENDMETHOD.

  METHOD vat_amount.
    rv_vat_amount = round( val = iv_net_amount * iv_vat_percentage / 100
                           dec = c_amount_decimals ).
  ENDMETHOD.

  METHOD gross_amount.
    rv_gross_amount = iv_net_amount + iv_vat_amount.
  ENDMETHOD.

ENDCLASS.

