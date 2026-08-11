ALTER TABLE `purchase_orders` MODIFY COLUMN `status` enum('draft','ordered','partially_received','received','cancelled') NOT NULL DEFAULT 'draft';
ALTER TABLE `po_items` ADD `supplier_item_id` char(36);
ALTER TABLE `po_items` ADD `supplier_sku` varchar(100);
ALTER TABLE `po_items` ADD `received_qty` int NOT NULL DEFAULT 0;
ALTER TABLE `po_items` ADD `cancelled_qty` int NOT NULL DEFAULT 0;
ALTER TABLE `po_items` ADD CONSTRAINT `po_items_supplier_item_id_supplier_items_id_fk` FOREIGN KEY (`supplier_item_id`) REFERENCES `supplier_items`(`id`);
