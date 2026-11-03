INTERFACE zif_merp_md_bus_partner_sel
  PUBLIC.

  TYPES ty_partner TYPE zmerp_r_bus_partner.
  TYPES tt_partners TYPE SORTED TABLE OF ty_partner WITH UNIQUE KEY PartnerCode.

  TYPES: BEGIN OF ty_partner_key,
           PartnerCode TYPE zmerp_r_bus_partner-PartnerCode,
         END OF ty_partner_key,
         tt_partner_keys TYPE STANDARD TABLE OF ty_partner_key WITH EMPTY KEY.

  TYPES: BEGIN OF ty_usage,
           PartnerCode  TYPE zmerp_r_bus_partner-PartnerCode,
           UsedInEntity   TYPE zmerp_entity_name,
           UsedAsSupplier TYPE abap_boolean,
           UsedAsCustomer TYPE abap_boolean,
           IsDocument   TYPE abap_boolean,
         END OF ty_usage,
         tt_usages TYPE SORTED TABLE OF ty_usage WITH UNIQUE KEY PartnerCode UsedInEntity.

  "! Reads master data for a single business partner
  "! @parameter iv_partner_code    | Requested business partner key
  "! @parameter rs_partner         | Returned business partner data structure
  "! @raising zcx_merp_md | Raised if the requested business partner does not exist
  METHODS read_partner
    IMPORTING iv_partner_code TYPE zmerp_r_bus_partner-PartnerCode
    RETURNING VALUE(rs_partner) TYPE ty_partner
    RAISING   zcx_merp_md.

  "! Reads master data for a list of business partners
  "! @parameter it_partner_keys | Table of business partner keys
  "! @parameter rt_partners     | Sorted table of existing business partners data
  METHODS read_partners
    IMPORTING it_partner_keys TYPE tt_partner_keys
    RETURNING VALUE(rt_partners) TYPE tt_partners.

  "! Reads where the given business partners are used (usage view): one row per code and using entity.
  "! Codes that are not used are not returned. UsedAsSupplier / UsedAsCustomer mark usage in purchasing /
  "! sales documents (the role flag cannot be removed); any usage blocks delete.
  "! @parameter it_partner_keys | Keys to check
  "! @parameter rt_usages       | Codes in use with the entity that uses them
  METHODS read_usages
    IMPORTING it_partner_keys TYPE tt_partner_keys
    RETURNING VALUE(rt_usages) TYPE tt_usages.

ENDINTERFACE.
