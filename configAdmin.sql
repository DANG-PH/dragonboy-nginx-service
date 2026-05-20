-- Tạo user
CREATE USER 'admin'@'%' IDENTIFIED BY 'haidang';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;

CREATE USER 'admin1'@'%' IDENTIFIED BY 'thanhle';
GRANT ALL PRIVILEGES ON *.* TO 'admin1'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;

CREATE USER 'admin2'@'%' IDENTIFIED BY 'duytu';
GRANT ALL PRIVILEGES ON *.* TO 'admin2'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;

CREATE USER 'admin3'@'%' IDENTIFIED BY 'dungle';
GRANT ALL PRIVILEGES ON *.* TO 'admin3'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;

-- Tạo database
-- CREATE DATABASE admin_db;
CREATE DATABASE auth_db;
CREATE DATABASE detu_db;
CREATE DATABASE item_db;
CREATE DATABASE user_db;
CREATE DATABASE social_db;
CREATE DATABASE pay_db;
CREATE DATABASE game_data_db;

-- Add sẵn các npc có sẵn vào game_data_db, kể cả chạy lại db khi container down và up lại
USE game_data_db;

-- game_data_db
CREATE TABLE npc_base (
    id        INT PRIMARY KEY AUTO_INCREMENT,
    ten       VARCHAR(50) NOT NULL UNIQUE,  -- "admin_haidang", client dùng làm asset key
    loai      ENUM('NGUOI','CAYDAU','RUONGDO','DUIGA') NOT NULL
);

INSERT IGNORE INTO npc_base (ten, loai) VALUES
('ong_gohan',       'NGUOI'),
('admin_haidang',   'NGUOI'),
('admin_thanhle',   'NGUOI'),
('admin_dungle',    'NGUOI'),
('thay_hieu',       'NGUOI'),
('admin_huykhoi',   'NGUOI'),
('vua_vegeta',      'NGUOI'),
('dau_traidat_1',   'CAYDAU'),
('dau_traidat_2',   'CAYDAU'),
('dau_traidat_3',   'CAYDAU'),
('dau_traidat_4',   'CAYDAU'),
('dau_traidat_5',   'CAYDAU'),
('dau_traidat_6',   'CAYDAU'),
('dau_traidat_7',   'CAYDAU'),
('dau_traidat_8',   'CAYDAU'),
('dau_traidat_9',   'CAYDAU'),
('dau_traidat_10',  'CAYDAU'),
('ruong_do',        'RUONGDO'),
('dui_ga',          'DUIGA');

CREATE TABLE map_base (
    id    INT PRIMARY KEY AUTO_INCREMENT,
    ten   VARCHAR(50) NOT NULL UNIQUE
);

INSERT IGNORE INTO map_base (ten) VALUES
('Nhà Gôhan'),
('Làng Aru'),
('Đồi Hoa Cúc');