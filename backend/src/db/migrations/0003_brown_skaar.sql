UPDATE `tickets`
SET `status` = CASE `status`
  WHEN 'open' THEN 'new'
  WHEN 'waiting_customer' THEN 'awaiting_customer'
  WHEN 'waiting_parts' THEN 'awaiting_parts'
  ELSE `status`
END
WHERE `status` IN ('open', 'waiting_customer', 'waiting_parts');--> statement-breakpoint
ALTER TABLE `tickets` MODIFY COLUMN `status` varchar(30) NOT NULL DEFAULT 'new';--> statement-breakpoint
ALTER TABLE `tickets` ADD `ticket_type` varchar(20) DEFAULT 'repair' NOT NULL;--> statement-breakpoint
ALTER TABLE `tickets` ADD `scheduled_at` timestamp;
