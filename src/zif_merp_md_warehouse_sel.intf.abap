INTERFACE zif_merp_md_warehouse_sel
  PUBLIC.

  TYPES ty_warehouse TYPE zmerp_r_warehouse.
  TYPES tt_warehouses TYPE SORTED TABLE OF ty_warehouse WITH UNIQUE KEY WarehouseCode.

  TYPES: BEGIN OF ty_warehouse_key,
           WarehouseCode TYPE zmerp_r_warehouse-WarehouseCode,
         END OF ty_warehouse_key,
         tt_warehouse_keys TYPE STANDARD TABLE OF ty_warehouse_key WITH EMPTY KEY.

  TYPES: BEGIN OF ty_usage,
           WarehouseCode TYPE zmerp_r_warehouse-WarehouseCode,
           UsedInEntity  TYPE zmerp_entity_name,
           IsDocument   TYPE abap_boolean,
         END OF ty_usage,
         tt_usages TYPE SORTED TABLE OF ty_usage WITH UNIQUE KEY WarehouseCode UsedInEntity.

  "! Reads master data for a single warehouse
  "! @parameter iv_warehouse_code  | Requested warehouse key
  "! @parameter rs_warehouse       | Returned warehouse data structure
  "! @raising zcx_merp_md | Raised if the warehouse does not exist
  METHODS read_warehouse
    IMPORTING iv_warehouse_code TYPE zmerp_r_warehouse-WarehouseCode
    RETURNING VALUE(rs_warehouse) TYPE ty_warehouse
    RAISING   zcx_merp_md.

  "! Reads master data for a list of warehouses
  "! @parameter it_warehouse_keys | Table of warehouse keys
  "! @parameter rt_warehouses     | Sorted table of existing warehouses data
  METHODS read_warehouses
    IMPORTING it_warehouse_keys TYPE tt_warehouse_keys
    RETURNING VALUE(rt_warehouses) TYPE tt_warehouses.

  "! Reads where the given warehouses are used (usage view): one row per code and using entity.
  "! Codes that are not used are not returned.
  "! @parameter it_warehouse_keys | Keys to check
  "! @parameter rt_usages         | Codes in use with the entity that uses them
  METHODS read_usages
    IMPORTING it_warehouse_keys TYPE tt_warehouse_keys
    RETURNING VALUE(rt_usages) TYPE tt_usages.

ENDINTERFACE.
