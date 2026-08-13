-- Runs automatically on first MariaDB boot (empty data volume).
-- Place your dump after this file, e.g. docker/db/01-kiosk_development.sql

CREATE DATABASE IF NOT EXISTS `kiosk_development`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS `kiosk_test`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
