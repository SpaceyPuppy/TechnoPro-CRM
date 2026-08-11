CREATE TABLE `stock_movements` (
  `id` char(36) NOT NULL,
  `inventory_item_id` char(36) NOT NULL,
  `quantity_delta` int NOT NULL,
  `unit_cost` decimal(10,2) NOT NULL,
  `value_delta` decimal(12,2) NOT NULL,
  `balance_after` int NOT NULL,
  `average_cost_after` decimal(10,2) NOT NULL,
  `source_type` enum('opening_balance','po_receipt','adjustment','sale','sale_reversal','return_to_supplier','stocktake','transfer') NOT NULL,
  `source_reference` varchar(191) NOT NULL,
  `reason_code` varchar(100) NOT NULL,
  `reason_note` text,
  `actor_user_id` char(36),
  `occurred_at` timestamp NOT NULL DEFAULT (now()),
  `created_at` timestamp NOT NULL DEFAULT (now()),
  CONSTRAINT `stock_movements_id` PRIMARY KEY(`id`),
  CONSTRAINT `stock_movements_source_reference_unique` UNIQUE(`source_reference`),
  CONSTRAINT `stock_movements_inventory_item_id_inventory_items_id_fk` FOREIGN KEY (`inventory_item_id`) REFERENCES `inventory_items`(`id`),
  CONSTRAINT `stock_movements_actor_user_id_users_id_fk` FOREIGN KEY (`actor_user_id`) REFERENCES `users`(`id`)
);
--> statement-breakpoint
CREATE INDEX `stock_movements_item_occurred_idx` ON `stock_movements` (`inventory_item_id`,`occurred_at`,`id`);
