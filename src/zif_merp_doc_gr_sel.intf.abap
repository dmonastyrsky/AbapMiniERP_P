"! Goods receipt selector. All methods read persisted (active) data only:
"! drafts and unsaved changes are not visible. Inside the goods receipt's own
"! handlers use READ ENTITIES ... IN LOCAL MODE instead.
INTERFACE zif_merp_doc_gr_sel
  PUBLIC.

  TYPES: BEGIN OF ty_document_key,
           DocumentUUID TYPE zmerp_r_goodsreceipt-DocumentUUID,
         END OF ty_document_key,
         tt_document_keys TYPE STANDARD TABLE OF ty_document_key WITH EMPTY KEY.

  TYPES: BEGIN OF ty_usage,
           DocumentUUID TYPE zmerp_r_goodsreceipt-DocumentUUID,
           UsedInEntity TYPE zmerp_entity_name,
         END OF ty_usage,
         tt_usages TYPE SORTED TABLE OF ty_usage WITH UNIQUE KEY DocumentUUID UsedInEntity.

  "! Reads where the given goods receipts are used (usage view): one row per document and using entity.
  "! Documents that are not used are not returned.
  "! @parameter it_document_keys | Keys to check
  "! @parameter rt_usages        | Documents in use with the entity that uses them
  METHODS read_usages
    IMPORTING it_document_keys TYPE tt_document_keys
    RETURNING VALUE(rt_usages) TYPE tt_usages.

ENDINTERFACE.
