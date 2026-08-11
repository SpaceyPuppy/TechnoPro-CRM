ALTER TABLE `inventory_items` ADD `upc` varchar(32);
ALTER TABLE `inventory_items` ADD `manufacturer_part_number` varchar(100);
ALTER TABLE `inventory_items` ADD `item_type` varchar(40) NOT NULL DEFAULT 'part';
ALTER TABLE `inventory_items` ADD `category` varchar(100);
ALTER TABLE `inventory_items` ADD `subcategory` varchar(100);
ALTER TABLE `inventory_items` ADD `brand` varchar(100);
ALTER TABLE `inventory_items` ADD `compatible_model` varchar(150);
ALTER TABLE `inventory_items` ADD `condition` varchar(40);
ALTER TABLE `inventory_items` ADD `reorder_point` int;
ALTER TABLE `inventory_items` ADD `target_stock_level` int;
ALTER TABLE `inventory_items` ADD `warranty_months` int;
ALTER TABLE `inventory_items` ADD `internal_notes` text;
ALTER TABLE `inventory_items` ADD `active` boolean NOT NULL DEFAULT true;
ALTER TABLE `inventory_items` ADD `pos_sellable` boolean NOT NULL DEFAULT true;
ALTER TABLE `inventory_items` ADD `serialized` boolean NOT NULL DEFAULT false;
CREATE TABLE `supplier_items` (
  `id` char(36) NOT NULL, `supplier_id` char(36) NOT NULL, `inventory_item_id` char(36) NOT NULL,
  `supplier_sku` varchar(100), `supplier_upc` varchar(32), `supplier_part_number` varchar(100), `product_url` varchar(1000),
  `pack_size` int NOT NULL DEFAULT 1, `minimum_order_qty` int NOT NULL DEFAULT 1,
  `quoted_unit_cost` decimal(10,2), `last_paid_unit_cost` decimal(10,2), `lead_time_days` int,
  `preferred` int NOT NULL DEFAULT 0, `active` int NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT (now()), `updated_at` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `supplier_items_id` PRIMARY KEY(`id`),
  CONSTRAINT `supplier_items_supplier_inventory_unique` UNIQUE(`supplier_id`,`inventory_item_id`),
  CONSTRAINT `supplier_items_supplier_sku_unique` UNIQUE(`supplier_id`,`supplier_sku`),
  CONSTRAINT `supplier_items_supplier_id_suppliers_id_fk` FOREIGN KEY (`supplier_id`) REFERENCES `suppliers`(`id`),
  CONSTRAINT `supplier_items_inventory_item_id_inventory_items_id_fk` FOREIGN KEY (`inventory_item_id`) REFERENCES `inventory_items`(`id`)
);
CREATE INDEX `supplier_items_inventory_active_idx` ON `supplier_items` (`inventory_item_id`,`active`);
