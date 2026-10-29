INTERFACE zif_merp_md_vat_rate_sel
  PUBLIC.

  TYPES ty_vat_rate TYPE zmerp_r_vat_rate.
  TYPES tt_vat_rates TYPE SORTED TABLE OF ty_vat_rate WITH UNIQUE KEY VatCode.

  TYPES: BEGIN OF ty_vat_rate_key,
           VatCode TYPE zmerp_r_vat_rate-VatCode,
         END OF ty_vat_rate_key,
         tt_vat_rate_keys TYPE STANDARD TABLE OF ty_vat_rate_key WITH EMPTY KEY.

  "! Reads master data for a single VAT rate
  "! @parameter iv_vat_code        | Requested VAT rate key
  "! @parameter rs_vat_rate        | Returned VAT rate data structure
  "! @raising zcx_merp_md | Raised if the requested VAT code does not exist
  METHODS read_vat_rate
    IMPORTING iv_vat_code TYPE zmerp_r_vat_rate-VatCode
    RETURNING VALUE(rs_vat_rate) TYPE ty_vat_rate
    RAISING   zcx_merp_md.

  "! Reads master data for a list of VAT rates
  "! @parameter it_vat_rate_keys | Table of VAT rate keys
  "! @parameter rt_vat_rates     | Sorted table of existing VAT rates data
  METHODS read_vat_rates
    IMPORTING it_vat_rate_keys TYPE tt_vat_rate_keys
    RETURNING VALUE(rt_vat_rates) TYPE tt_vat_rates.

  "! Validates VAT codes and returns missing/invalid keys
  "! @parameter it_vat_rate_keys | Table of VAT rate keys to validate
  "! @parameter rt_invalid_keys  | Table containing only keys that do not exist in DB
  METHODS validate_vat_rates
    IMPORTING it_vat_rate_keys      TYPE tt_vat_rate_keys
    RETURNING VALUE(rt_invalid_keys) TYPE tt_vat_rate_keys.

ENDINTERFACE.
