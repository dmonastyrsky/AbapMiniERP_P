INTERFACE zif_merp_doc_st_sel
  PUBLIC.

  TYPES: BEGIN OF ty_document_key,
           DocumentUUID TYPE zmerp_r_stocktransfer-DocumentUUID,
         END OF ty_document_key,
         tt_document_keys TYPE STANDARD TABLE OF ty_document_key WITH EMPTY KEY.

  TYPES: BEGIN OF ty_usage,
           DocumentUUID TYPE zmerp_r_stocktransfer-DocumentUUID,
           UsedInEntity TYPE zmerp_entity_name,
         END OF ty_usage,
         tt_usages TYPE SORTED TABLE OF ty_usage WITH UNIQUE KEY DocumentUUID UsedInEntity.

  "! Entities that use the given stock transfers (delete check)
  METHODS read_usages
    IMPORTING it_document_keys TYPE tt_document_keys
    RETURNING VALUE(rt_usages) TYPE tt_usages.
ENDINTERFACE.
