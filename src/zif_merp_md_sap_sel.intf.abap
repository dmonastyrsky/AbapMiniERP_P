"! Selector for SAP standard master data (currency, country, unit of measure).
"! Only existence is needed: own master data reference these codes, documents copy them (MD1, MD8).
INTERFACE zif_merp_md_sap_sel
  PUBLIC.

  TYPES: BEGIN OF ty_currency_key,
           Currency TYPE i_currency-Currency,
         END OF ty_currency_key,
         tt_currency_keys TYPE STANDARD TABLE OF ty_currency_key WITH EMPTY KEY,
         tt_currencies    TYPE SORTED TABLE OF ty_currency_key WITH UNIQUE KEY Currency.

  TYPES: BEGIN OF ty_country_key,
           Country TYPE i_country-Country,
         END OF ty_country_key,
         tt_country_keys TYPE STANDARD TABLE OF ty_country_key WITH EMPTY KEY,
         tt_countries    TYPE SORTED TABLE OF ty_country_key WITH UNIQUE KEY Country.

  TYPES: BEGIN OF ty_unit_key,
           UnitOfMeasure TYPE i_unitofmeasure-UnitOfMeasure,
         END OF ty_unit_key,
         tt_unit_keys TYPE STANDARD TABLE OF ty_unit_key WITH EMPTY KEY,
         tt_units     TYPE SORTED TABLE OF ty_unit_key WITH UNIQUE KEY UnitOfMeasure.

  "! Returns the currencies of the list that exist (initial and duplicate keys are ignored)
  "! @parameter it_currency_keys | Currencies to check
  "! @parameter rt_currencies    | Existing currencies
  METHODS read_currencies
    IMPORTING it_currency_keys     TYPE tt_currency_keys
    RETURNING VALUE(rt_currencies) TYPE tt_currencies.

  "! Returns the countries of the list that exist (initial and duplicate keys are ignored)
  "! @parameter it_country_keys | Countries to check
  "! @parameter rt_countries    | Existing countries
  METHODS read_countries
    IMPORTING it_country_keys     TYPE tt_country_keys
    RETURNING VALUE(rt_countries) TYPE tt_countries.

  "! Returns the units of measure of the list that exist (initial and duplicate keys are ignored)
  "! @parameter it_unit_keys | Units to check
  "! @parameter rt_units     | Existing units
  METHODS read_units
    IMPORTING it_unit_keys     TYPE tt_unit_keys
    RETURNING VALUE(rt_units) TYPE tt_units.

ENDINTERFACE.
