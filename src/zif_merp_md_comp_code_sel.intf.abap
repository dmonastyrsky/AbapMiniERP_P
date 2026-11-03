INTERFACE zif_merp_md_comp_code_sel
  PUBLIC.

  TYPES ty_company TYPE zmerp_r_company_code.
  TYPES tt_companies TYPE SORTED TABLE OF ty_company WITH UNIQUE KEY CompanyCode.

  TYPES: BEGIN OF ty_company_key,
           CompanyCode TYPE zmerp_r_company_code-CompanyCode,
         END OF ty_company_key,
         tt_company_keys TYPE STANDARD TABLE OF ty_company_key WITH EMPTY KEY.

  TYPES: BEGIN OF ty_usage,
           CompanyCode  TYPE zmerp_r_company_code-CompanyCode,
           UsedInEntity TYPE zmerp_entity_name,
           IsDocument   TYPE abap_boolean,
         END OF ty_usage,
         tt_usages TYPE SORTED TABLE OF ty_usage WITH UNIQUE KEY CompanyCode UsedInEntity.

  "! Reads master data for a single company code
  "! @parameter iv_company_code    | Requested company code key
  "! @parameter rs_company         | Returned master data structure
  "! @raising zcx_merp_md | Raised if the company code does not exist or input is initial
  METHODS read_company
    IMPORTING iv_company_code TYPE zmerp_r_company_code-CompanyCode
    RETURNING VALUE(rs_company) TYPE ty_company
    RAISING   zcx_merp_md.

  "! Reads master data for a list of company codes
  "! @parameter it_company_keys | Table of company code keys
  "! @parameter rt_companies    | Sorted table of existing company codes data
  METHODS read_companies
    IMPORTING it_company_keys TYPE tt_company_keys
    RETURNING VALUE(rt_companies) TYPE tt_companies.

  "! Reads where the given company codes are used (usage view): one row per code and using entity.
  "! Codes that are not used are not returned. IsDocument marks usage in documents (critical fields);
  "! any usage blocks delete.
  "! @parameter it_company_keys | Keys to check
  "! @parameter rt_usages       | Codes in use with the entity that uses them
  METHODS read_usages
    IMPORTING it_company_keys TYPE tt_company_keys
    RETURNING VALUE(rt_usages) TYPE tt_usages.

ENDINTERFACE.
