ALTER TABLE `time_entries` ADD `running_user_id` char(36);--> statement-breakpoint
ALTER TABLE `time_entries` ADD CONSTRAINT `time_entries_running_user_id_unique` UNIQUE(`running_user_id`);--> statement-breakpoint
ALTER TABLE `time_entries` ADD CONSTRAINT `time_entries_running_user_id_users_id_fk` FOREIGN KEY (`running_user_id`) REFERENCES `users`(`id`) ON DELETE no action ON UPDATE no action;