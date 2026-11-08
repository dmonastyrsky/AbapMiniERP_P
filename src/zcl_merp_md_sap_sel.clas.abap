CLASS zcl_merp_md_sap_sel DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_merp_md_sap_sel.
ENDCLASS.


CLASS zcl_merp_md_sap_sel IMPLEMENTATION.

  METHOD zif_merp_md_sap_sel~read_currencies.
    DATA(lt_keys) = it_currency_keys.
    DELETE lt_keys WHERE Currency IS INITIAL.
    SORT lt_keys BY Currency.
    DELETE ADJACENT DUPLICATES FROM lt_keys COMPARING Currency.

    IF lt_keys IS INITIAL.
      RETURN.
    ENDIF.

    SELECT cur~Currency
      FROM i_currency AS cur
      INNER JOIN @lt_keys AS keys ON cur~Currency = keys~Currency
      INTO TABLE @rt_currencies.
  ENDMETHOD.

  METHOD zif_merp_md_sap_sel~read_countries.
    DATA(lt_keys) = it_country_keys.
    DELETE lt_keys WHERE Country IS INITIAL.
    SORT lt_keys BY Country.
    DELETE ADJACENT DUPLICATES FROM lt_keys COMPARING Country.

    IF lt_keys IS INITIAL.
      RETURN.
    ENDIF.

    SELECT cntr~Country
      FROM i_country AS cntr
      INNER JOIN @lt_keys AS keys ON cntr~Country = keys~Country
      INTO TABLE @rt_countries.
  ENDMETHOD.

  METHOD zif_merp_md_sap_sel~read_units.
    DATA(lt_keys) = it_unit_keys.
    DELETE lt_keys WHERE UnitOfMeasure IS INITIAL.
    SORT lt_keys BY UnitOfMeasure.
    DELETE ADJACENT DUPLICATES FROM lt_keys COMPARING UnitOfMeasure.

    IF lt_keys IS INITIAL.
      RETURN.
    ENDIF.

    SELECT uom~UnitOfMeasure
      FROM i_unitofmeasure AS uom
      INNER JOIN @lt_keys AS keys ON uom~UnitOfMeasure = keys~UnitOfMeasure
      INTO TABLE @rt_units.
  ENDMETHOD.

ENDCLASS.
