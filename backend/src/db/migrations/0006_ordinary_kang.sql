CREATE TABLE `audit_events` (
	`id` char(36) NOT NULL,
	`entity_type` varchar(40) NOT NULL,
	`entity_id` char(36) NOT NULL,
	`action` varchar(60) NOT NULL,
	`user_id` char(36),
	`data` text,
	`created_at` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `audit_events_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
ALTER TABLE `audit_events` ADD CONSTRAINT `audit_events_user_id_users_id_fk` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE no action ON UPDATE no action;