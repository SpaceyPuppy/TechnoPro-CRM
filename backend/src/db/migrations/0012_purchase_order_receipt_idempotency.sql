CREATE TABLE `purchase_order_receipt_lines` (
  `id` char(36) NOT NULL,
  `po_item_id` char(36) NOT NULL,
  `receipt_reference` varchar(100) NOT NULL,
  `received_qty` int NOT NULL DEFAULT 0,
  `cancelled_qty` int NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT (now()),
  CONSTRAINT `purchase_order_receipt_lines_id` PRIMARY KEY(`id`),
  CONSTRAINT `purchase_order_receipt_lines_item_reference_unique` UNIQUE(`po_item_id`,`receipt_reference`),
  CONSTRAINT `purchase_order_receipt_lines_po_item_id_po_items_id_fk` FOREIGN KEY (`po_item_id`) REFERENCES `po_items`(`id`)
);
