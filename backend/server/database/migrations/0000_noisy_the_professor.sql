CREATE TABLE `equipment` (
	`id` int AUTO_INCREMENT NOT NULL,
	`site_id` int NOT NULL,
	`tip` enum('asansor','yuruyen_merdiven') NOT NULL,
	`marka` varchar(255),
	`model` varchar(255),
	`seri_no` varchar(100),
	`kurulum_tarihi` timestamp,
	`created_at` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `equipment_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `materials` (
	`id` int AUTO_INCREMENT NOT NULL,
	`ad` varchar(255) NOT NULL,
	`birim` varchar(50),
	`stok_adedi` int NOT NULL DEFAULT 0,
	CONSTRAINT `materials_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `notifications` (
	`id` int AUTO_INCREMENT NOT NULL,
	`user_id` int NOT NULL,
	`tip` varchar(50) NOT NULL,
	`mesaj` text NOT NULL,
	`okundu` boolean NOT NULL DEFAULT false,
	`created_at` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `notifications_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `sites` (
	`id` int AUTO_INCREMENT NOT NULL,
	`ad` varchar(255) NOT NULL,
	`adres` text,
	`lat` decimal(10,7),
	`lng` decimal(10,7),
	`denetci_user_id` int,
	`created_at` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `sites_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `teams` (
	`id` int AUTO_INCREMENT NOT NULL,
	`ad` varchar(255) NOT NULL,
	`tip` enum('ariza','bakim','kontrol') NOT NULL,
	`sorumlu_user_id` int,
	`created_at` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `teams_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `user_locations` (
	`user_id` int NOT NULL,
	`lat` decimal(10,7) NOT NULL,
	`lng` decimal(10,7) NOT NULL,
	`updated_at` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `user_locations_user_id` PRIMARY KEY(`user_id`)
);
--> statement-breakpoint
CREATE TABLE `users` (
	`id` int AUTO_INCREMENT NOT NULL,
	`ad` varchar(255) NOT NULL,
	`email` varchar(255) NOT NULL,
	`telefon` varchar(30),
	`password_hash` varchar(255) NOT NULL,
	`taraf` enum('isveren','alt_yuklenici') NOT NULL,
	`rol` enum('yonetici','denetci','sorumlu','ariza_ekibi','bakim_ekibi','kontrol_ekibi') NOT NULL,
	`aktif` boolean NOT NULL DEFAULT true,
	`takim_id` int,
	`created_at` timestamp NOT NULL DEFAULT (now()),
	`updated_at` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `users_id` PRIMARY KEY(`id`),
	CONSTRAINT `users_email_unique` UNIQUE(`email`)
);
--> statement-breakpoint
CREATE TABLE `work_order_materials` (
	`work_order_id` int NOT NULL,
	`material_id` int NOT NULL,
	`miktar` decimal(10,2) NOT NULL,
	CONSTRAINT `work_order_materials_work_order_id_material_id_pk` PRIMARY KEY(`work_order_id`,`material_id`)
);
--> statement-breakpoint
CREATE TABLE `work_order_photos` (
	`id` int AUTO_INCREMENT NOT NULL,
	`work_order_id` int NOT NULL,
	`url` varchar(500) NOT NULL,
	`gps_lat` decimal(10,7) NOT NULL,
	`gps_lng` decimal(10,7) NOT NULL,
	`cekim_zamani` timestamp NOT NULL,
	`yukleyen_user_id` int NOT NULL,
	`boyut_kb` int,
	`created_at` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `work_order_photos_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `work_order_reviews` (
	`id` int AUTO_INCREMENT NOT NULL,
	`work_order_id` int NOT NULL,
	`reviewer_user_id` int NOT NULL,
	`sonuc` enum('onay','red') NOT NULL,
	`gerekce` text,
	`incelenen_zaman` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `work_order_reviews_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `work_order_timeline` (
	`id` int AUTO_INCREMENT NOT NULL,
	`work_order_id` int NOT NULL,
	`durum` enum('bekliyor','devam_edecek','tamamlandi','onay_bekliyor','onaylandi','reddedildi','na') NOT NULL,
	`not` text,
	`created_by_user_id` int,
	`created_at` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `work_order_timeline_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `work_orders` (
	`id` int AUTO_INCREMENT NOT NULL,
	`equipment_id` int NOT NULL,
	`tip` enum('bakim','ariza','kontrol') NOT NULL,
	`atanan_user_id` int,
	`oncelik` varchar(20),
	`durum` enum('bekliyor','devam_edecek','tamamlandi','onay_bekliyor','onaylandi','reddedildi','na') NOT NULL DEFAULT 'bekliyor',
	`aciklama` text,
	`parent_work_order_id` int,
	`occurred_at` timestamp,
	`reported_at` timestamp,
	`reported_at_server` timestamp,
	`response_started_at` timestamp,
	`resolved_at` timestamp,
	`resolved_by_user_id` int,
	`created_at` timestamp NOT NULL DEFAULT (now()),
	`updated_at` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `work_orders_id` PRIMARY KEY(`id`)
);
