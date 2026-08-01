CREATE TABLE `ticket_checklist_items` (
	`id` char(36) NOT NULL,
	`ticket_id` char(36) NOT NULL,
	`content` varchar(500) NOT NULL,
	`completed` boolean NOT NULL DEFAULT false,
	`sort_order` int NOT NULL DEFAULT 0,
	`created_at` timestamp NOT NULL DEFAULT (now()),
	`updated_at` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `ticket_checklist_items_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
ALTER TABLE `ticket_checklist_items` ADD CONSTRAINT `ticket_checklist_items_ticket_id_tickets_id_fk` FOREIGN KEY (`ticket_id`) REFERENCES `tickets`(`id`) ON DELETE no action ON UPDATE no action;