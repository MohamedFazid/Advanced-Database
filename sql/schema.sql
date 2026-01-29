-- ===============================
-- FOOTBALL ANALYSIS DATABASE
-- ===============================

CREATE DATABASE IF NOT EXISTS football_analysis
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE football_analysis;

-- ===============================
-- LEAGUE TABLE
-- ===============================

CREATE TABLE league (
    league_id    INT AUTO_INCREMENT PRIMARY KEY,
    code         VARCHAR(10)  NOT NULL,
    name         VARCHAR(100) NOT NULL,
    country      VARCHAR(100) NOT NULL,
    UNIQUE (code)
) ENGINE=InnoDB;

-- ===============================
-- SEASON TABLE
-- ===============================

CREATE TABLE season (
    season_id    INT AUTO_INCREMENT PRIMARY KEY,
    name         VARCHAR(20) NOT NULL,
    start_year   SMALLINT    NOT NULL,
    end_year     SMALLINT    NOT NULL,
    UNIQUE (name)
) ENGINE=InnoDB;

-- ===============================
-- TEAM TABLE
-- ===============================

CREATE TABLE team (
    team_id      INT AUTO_INCREMENT PRIMARY KEY,
    name         VARCHAR(100) NOT NULL,
    short_name   VARCHAR(20) NULL,
    UNIQUE (name)
) ENGINE=InnoDB;

-- ===============================
-- REFEREE TABLE
-- ===============================

CREATE TABLE referee (
    referee_id   INT AUTO_INCREMENT PRIMARY KEY,
    name         VARCHAR(100) NOT NULL,
    UNIQUE (name)
) ENGINE=InnoDB;

-- ===============================
-- BOOKMAKER TABLE
-- ===============================

CREATE TABLE bookmaker (
    bookmaker_id INT AUTO_INCREMENT PRIMARY KEY,
    code         VARCHAR(20)  NOT NULL,
    name         VARCHAR(100) NOT NULL,
    UNIQUE (code)
) ENGINE=InnoDB;

-- insert Bet365 as default bookmaker
INSERT INTO bookmaker (code, name)
VALUES ('B365', 'Bet365')
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- ===============================
-- MATCH TABLE (FACT TABLE)
-- ===============================

CREATE TABLE `match` (
    match_id              INT AUTO_INCREMENT PRIMARY KEY,
    
    league_id             INT NOT NULL,
    season_id             INT NOT NULL,
    
    match_date            DATE NOT NULL,
    match_time            TIME NULL,

    home_team_id          INT NOT NULL,
    away_team_id          INT NOT NULL,

    full_time_home_goals  TINYINT NOT NULL,
    full_time_away_goals  TINYINT NOT NULL,
    full_time_result      ENUM('H','D','A') NOT NULL,

    half_time_home_goals  TINYINT NOT NULL,
    half_time_away_goals  TINYINT NOT NULL,
    half_time_result      ENUM('H','D','A') NULL,

    referee_id            INT NULL,

    home_shots            SMALLINT NULL,
    away_shots            SMALLINT NULL,

    home_shots_on_target  SMALLINT NULL,
    away_shots_on_target  SMALLINT NULL,

    home_fouls            SMALLINT NULL,
    away_fouls            SMALLINT NULL,

    home_corners          SMALLINT NULL,
    away_corners          SMALLINT NULL,

    home_yellow_cards     SMALLINT NULL,
    away_yellow_cards     SMALLINT NULL,
    home_red_cards        SMALLINT NULL,
    away_red_cards        SMALLINT NULL,

    original_div_code     VARCHAR(10) NULL,

    CONSTRAINT fk_match_league
      FOREIGN KEY (league_id) REFERENCES league (league_id),

    CONSTRAINT fk_match_season
      FOREIGN KEY (season_id) REFERENCES season (season_id),

    CONSTRAINT fk_match_home_team
      FOREIGN KEY (home_team_id) REFERENCES team (team_id),

    CONSTRAINT fk_match_away_team
      FOREIGN KEY (away_team_id) REFERENCES team (team_id),

    CONSTRAINT fk_match_referee
      FOREIGN KEY (referee_id) REFERENCES referee (referee_id)
) ENGINE=InnoDB;

-- ===============================
-- MATCH ODDS TABLE
-- ===============================

CREATE TABLE match_odds (
    match_id        INT NOT NULL,
    bookmaker_id    INT NOT NULL,

    home_win_odds   DECIMAL(6,2) NULL,
    draw_odds       DECIMAL(6,2) NULL,
    away_win_odds   DECIMAL(6,2) NULL,

    PRIMARY KEY (match_id, bookmaker_id),

    CONSTRAINT fk_odds_match
      FOREIGN KEY (match_id) REFERENCES `match` (match_id)
      ON DELETE CASCADE,

    CONSTRAINT fk_odds_bookmaker
      FOREIGN KEY (bookmaker_id) REFERENCES bookmaker (bookmaker_id)
) ENGINE=InnoDB;



