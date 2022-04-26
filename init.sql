/*
  CREATE USER '_site_db_user_'@'localhost' IDENTIFIED BY '_STRONG_PASSWORD_';
  CREATE DATABASE _site_database_ CHARACTER SET utf8 COLLATE utf8_general_ci;
  GRANT ALL PRIVILEGES ON _site_database_.* TO '_site_db_user_'@'localhost';
  GRANT FILE ON *.* TO '_site_db_user_'@'localhost';
  USE _site_database_;
*/

CREATE TABLE langs (
  `id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(32) NOT NULL DEFAULT '',
  `nick` CHAR(2) NOT NULL DEFAULT '',
  `isocode` CHAR(2) NOT NULL DEFAULT '',
  PRIMARY KEY (id)
) CHARACTER SET utf8 COLLATE utf8_general_ci ENGINE InnoDB;

/* insert site primary language with empty 'nick' */
INSERT INTO langs (`name`, `nick`, `isocode`) VALUES ('Eng', '', 'en');

CREATE TABLE pages (
  `id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `parent_id` INT(10) UNSIGNED NOT NULL DEFAULT '0',
  `priority` INT(10) UNSIGNED NOT NULL DEFAULT '0',
  `hidden` TINYINT(1) UNSIGNED NOT NULL DEFAULT '0',
  `navi_on` TINYINT(1) UNSIGNED NOT NULL DEFAULT '1',
  `changed` TINYINT(1) UNSIGNED NOT NULL DEFAULT '1',
  `mode` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',
  `child_qty` INT(10) UNSIGNED NOT NULL DEFAULT '0',
  `good_qty` INT(10) UNSIGNED NOT NULL DEFAULT '0',
  `name` VARCHAR(128) NOT NULL DEFAULT '',
  `nick` VARCHAR(128) NOT NULL DEFAULT '',
  PRIMARY KEY (id)
) CHARACTER SET utf8 COLLATE utf8_general_ci ENGINE InnoDB;

/* insert site home page in primary language */
INSERT INTO pages (`name`) VALUES ('Home');

CREATE TABLE page_marks (
  `id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `page_id` INT(10) UNSIGNED NOT NULL DEFAULT '0',
  `lang_id` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',
  `name` CHAR(16) NOT NULL DEFAULT '',
  `value` TEXT NOT NULL,
  PRIMARY KEY (id),
  UNIQUE INDEX mark_idx (`page_id`, `lang_id`, `name`)
) CHARACTER SET utf8 COLLATE utf8_general_ci ENGINE InnoDB;

/*
  pre-seed some common page marks
  insert page_title for meta title
  insert page_name for navigation link
*/
INSERT INTO page_marks (`page_id`, `lang_id`, `name`, `value`) VALUES (1, 1, 'page_title', 'Home');
INSERT INTO page_marks (`page_id`, `lang_id`, `name`, `value`) VALUES (1, 1, 'page_name', 'Home');
INSERT INTO page_marks (`page_id`, `lang_id`, `name`, `value`) VALUES (1, 1, 'page_descr', '');
INSERT INTO page_marks (`page_id`, `lang_id`, `name`, `value`) VALUES (1, 1, 'page_main', '');

CREATE TABLE global_marks (
  `id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` CHAR(16) NOT NULL DEFAULT '',
  `value` TEXT NOT NULL,
  PRIMARY KEY (id)
) CHARACTER SET utf8 COLLATE utf8_general_ci ENGINE InnoDB;

/*
  shop is work in progress
*/
CREATE TABLE suppliers (
  `id`    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`  VARCHAR(32) NOT NULL DEFAULT '',
  `title` VARCHAR(255) NOT NULL DEFAULT '',
  `city`  VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (id)
) CHARACTER SET utf8 COLLATE utf8_general_ci ENGINE InnoDB;

CREATE TABLE goods_categories (
  `good_id` INT(10) UNSIGNED NOT NULL DEFAULT '0',
  `cat_id` INT(10) UNSIGNED NOT NULL DEFAULT '0',
  PRIMARY KEY (`good_id`,`cat_id`)
) CHARACTER SET utf8 COLLATE utf8_general_ci ENGINE InnoDB;

CREATE TABLE goods_colors (
  `id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(64) NOT NULL DEFAULT '',
  `name_md5` CHAR(32) NOT NULL DEFAULT '',
  `value` VARCHAR(16) NOT NULL DEFAULT '',
  PRIMARY KEY (id),
  UNIQUE KEY name_idx (`name_md5`)
) CHARACTER SET utf8 COLLATE utf8_general_ci ENGINE InnoDB;

CREATE TABLE goods_sizes (
  `id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(8) NOT NULL DEFAULT '',
  PRIMARY KEY (id),
  UNIQUE KEY name_idx (`name`)
) CHARACTER SET utf8 COLLATE utf8_general_ci ENGINE InnoDB;

INSERT INTO goods_sizes (`name`) VALUES ('40');
INSERT INTO goods_sizes (`name`) VALUES ('42');
INSERT INTO goods_sizes (`name`) VALUES ('44');
INSERT INTO goods_sizes (`name`) VALUES ('46');
INSERT INTO goods_sizes (`name`) VALUES ('48');
INSERT INTO goods_sizes (`name`) VALUES ('50');
INSERT INTO goods_sizes (`name`) VALUES ('52');
INSERT INTO goods_sizes (`name`) VALUES ('54');
INSERT INTO goods_sizes (`name`) VALUES ('56');
INSERT INTO goods_sizes (`name`) VALUES ('58');
INSERT INTO goods_sizes (`name`) VALUES ('60');
INSERT INTO goods_sizes (`name`) VALUES ('62');
INSERT INTO goods_sizes (`name`) VALUES ('64');
INSERT INTO goods_sizes (`name`) VALUES ('66');

CREATE TABLE goods (
  `id`      INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `hidden`  TINYINT(1) UNSIGNED NOT NULL DEFAULT '0',
  `changed` TINYINT(1) UNSIGNED NOT NULL DEFAULT '0',
  `sup_id`  INT(10) UNSIGNED NOT NULL DEFAULT '0',
  `price`   DECIMAL(12,4) NOT NULL DEFAULT 0,
  `code` VARCHAR(32) NOT NULL DEFAULT '',
  `name` VARCHAR(255) NOT NULL DEFAULT '',
  `nick` VARCHAR(128) NOT NULL DEFAULT '',
  `img_path_sm` VARCHAR(255) NOT NULL DEFAULT '',
  `img_path_la` VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (id),
  UNIQUE KEY sup_code_idx (`sup_id`,`code`)
) CHARACTER SET utf8 COLLATE utf8_general_ci ENGINE InnoDB;

CREATE TABLE goods_versions (
  `id`      INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `good_id` INT(10) UNSIGNED NOT NULL DEFAULT '0',
  `lang_id` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',
  `name`    VARCHAR(255) NOT NULL DEFAULT '',
  `p_title` VARCHAR(255) NOT NULL DEFAULT '',
  `p_descr` VARCHAR(255) NOT NULL DEFAULT '',
  `descr`   TEXT NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY version_idx (`good_id`, `lang_id`)
) CHARACTER SET utf8 COLLATE utf8_general_ci ENGINE InnoDB;

CREATE TABLE goods_offers (
  `id`       INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `good_id`  INT(10) UNSIGNED NOT NULL DEFAULT '0',
  `color_id` INT(10) UNSIGNED NOT NULL DEFAULT '0',
  `size_id`  INT(10) UNSIGNED NOT NULL DEFAULT '0',
  `qty`      INT(10) UNSIGNED NOT NULL DEFAULT '0',
  `price`    DECIMAL(12,4) NOT NULL DEFAULT 0,
  `price2`   DECIMAL(12,4) NOT NULL DEFAULT 0,
  `discount` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',
  PRIMARY KEY (id),
  UNIQUE KEY offer_idx (`good_id`,`color_id`, `size_id`)
) CHARACTER SET utf8 COLLATE utf8_general_ci ENGINE InnoDB;

CREATE TABLE goods_images (
  `id`      INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `good_id` INT(10) UNSIGNED NOT NULL DEFAULT '0',
  `num`     TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',
  `url`     VARCHAR(255) NOT NULL DEFAULT '',
  `path_sm` VARCHAR(255) NOT NULL DEFAULT '',
  `path_la` VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (id),
  UNIQUE KEY good_url_idx (`good_id`,`url`),
  INDEX good_idx (`good_id`)
) CHARACTER SET utf8 COLLATE utf8_general_ci ENGINE InnoDB;

/*
  Notes is CMS module
*/

CREATE TABLE notes (
  `id`      INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `page_id` INT(10) UNSIGNED NOT NULL DEFAULT 0,
  `hidden`  TINYINT(1) UNSIGNED NOT NULL DEFAULT 0,
  `prio`    INT(10) UNSIGNED NOT NULL DEFAULT 0,
  `add_dt`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `price`   DECIMAL(12,2) NOT NULL DEFAULT 0,
  `nick`    VARCHAR(128) NOT NULL DEFAULT '',
  `is_ext`  TINYINT(1) UNSIGNED NOT NULL DEFAULT 0,
  `ip`      VARCHAR(45) NOT NULL DEFAULT '',
  PRIMARY KEY (id)
) CHARACTER SET utf8 COLLATE utf8_general_ci ENGINE InnoDB;

CREATE TABLE notes_versions (
  `id`      INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `note_id` INT(10) UNSIGNED NOT NULL DEFAULT 0,
  `lang_id` TINYINT(3) UNSIGNED NOT NULL DEFAULT 0,
  `name`    VARCHAR(255) NOT NULL DEFAULT '',
  `param_01` VARCHAR(255) NOT NULL DEFAULT '',
  `param_02` VARCHAR(255) NOT NULL DEFAULT '',
  `param_03` VARCHAR(255) NOT NULL DEFAULT '',
  `param_04` VARCHAR(255) NOT NULL DEFAULT '',
  `param_05` VARCHAR(255) NOT NULL DEFAULT '',
  `p_title` VARCHAR(255) NOT NULL DEFAULT '',
  `p_descr` VARCHAR(255) NOT NULL DEFAULT '',
  `descr`   TEXT NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY version_idx (`note_id`, `lang_id`)
) CHARACTER SET utf8 COLLATE utf8_general_ci ENGINE InnoDB;

CREATE TABLE notes_images (
  `id`      INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `note_id` INT(10) UNSIGNED NOT NULL DEFAULT 0,
  `num`     TINYINT(3) UNSIGNED NOT NULL DEFAULT 0,
  `path_sm` VARCHAR(255) NOT NULL DEFAULT '',
  `path_la` VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (id),
  INDEX note_idx (`note_id`)
) CHARACTER SET utf8 COLLATE utf8_general_ci ENGINE InnoDB;

/*
  session is for User app
*/

CREATE TABLE sess (
  `id`           CHAR(40) NOT NULL DEFAULT '',
  `updated_at`   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `cust_id`      INT UNSIGNED NOT NULL DEFAULT 0,
  `otp_sha1hex`  CHAR(40) NOT NULL DEFAULT '',
  `ip`           VARCHAR(45) NOT NULL DEFAULT '',
  `ua`           VARCHAR(255) NOT NULL DEFAULT '',
  `email`        VARCHAR(255) NOT NULL DEFAULT '',
  `dest_area_id` INT UNSIGNED NOT NULL DEFAULT 0,
  `dest_city_id` INT UNSIGNED NOT NULL DEFAULT 0,
  `dest_wh_id`   INT UNSIGNED NOT NULL DEFAULT 0,
  `dest_id`      INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  INDEX otp_idx (`otp_sha1hex`)
) CHARACTER SET utf8 COLLATE utf8_general_ci ENGINE InnoDB;

CREATE TABLE sess_goods (
  `sess_id` CHAR(40) NOT NULL DEFAULT '',
  `sup_id` INT(10) UNSIGNED NOT NULL DEFAULT 0,
  `good_code` VARCHAR(32) NOT NULL DEFAULT '',
  `good_qty` INT(10) UNSIGNED NOT NULL DEFAULT 0,
  `good_price` DECIMAL(12,4) NOT NULL DEFAULT 0,
  `color_id` INT(10) UNSIGNED NOT NULL DEFAULT 0,
  `size_id`  INT(10) UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`sess_id`,`sup_id`,`good_code`, `color_id`, `size_id`),
  INDEX sess_idx (`sess_id`)
) CHARACTER SET utf8 COLLATE utf8_general_ci ENGINE InnoDB;

/*
  these tables are for TheSchwartz job queue
*/

CREATE TABLE funcmap (
  funcid         INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
  funcname       VARCHAR(255) NOT NULL,
  UNIQUE(funcname)
);
CREATE TABLE job (
  jobid           BIGINT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
  funcid          INT UNSIGNED NOT NULL,
  arg             MEDIUMBLOB,
  uniqkey         VARCHAR(255) NULL,
  insert_time     INT UNSIGNED,
  run_after       INT UNSIGNED NOT NULL,
  grabbed_until   INT UNSIGNED NOT NULL,
  priority        SMALLINT UNSIGNED,
  coalesce        VARCHAR(255),
  INDEX (funcid, run_after),
  UNIQUE(funcid, uniqkey),
  INDEX (funcid, coalesce)
);
CREATE TABLE note (
  jobid           BIGINT UNSIGNED NOT NULL,
  notekey         VARCHAR(255),
  PRIMARY KEY (jobid, notekey),
  value           MEDIUMBLOB
);
CREATE TABLE error (
  error_time      INT UNSIGNED NOT NULL,
  jobid           BIGINT UNSIGNED NOT NULL,
  message         VARCHAR(255) NOT NULL,
  funcid          INT UNSIGNED NOT NULL DEFAULT 0,
  INDEX (funcid, error_time),
  INDEX (error_time),
  INDEX (jobid)
);
CREATE TABLE exitstatus (
  jobid           BIGINT UNSIGNED PRIMARY KEY NOT NULL,
  funcid          INT UNSIGNED NOT NULL DEFAULT 0,
  status          SMALLINT UNSIGNED,
  completion_time INT UNSIGNED,
  delete_after    INT UNSIGNED,
  INDEX (funcid),
  INDEX (delete_after)
);