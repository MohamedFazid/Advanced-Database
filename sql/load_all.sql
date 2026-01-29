-- =====================================
-- DATA LOADING SCRIPT
-- Loads all 5 seasons into the schema
-- =====================================

USE football_analysis;

-- -------------------------------------
-- 0. Reference data: league + seasons
-- -------------------------------------
INSERT INTO league (code, name, country)
VALUES ('E0', 'Premier League', 'England')
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  country = VALUES(country);

INSERT INTO season (name, start_year, end_year)
VALUES
('2020-2021', 2020, 2021),
('2021-2022', 2021, 2022),
('2022-2023', 2022, 2023),
('2023-2024', 2023, 2024),
('2024-2025', 2024, 2025)
ON DUPLICATE KEY UPDATE
  start_year = VALUES(start_year),
  end_year   = VALUES(end_year);

-- -------------------------------------
-- 1. Reset data so script is re-runnable
-- -------------------------------------
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE match_odds;
TRUNCATE TABLE `match`;
TRUNCATE TABLE referee;
TRUNCATE TABLE team;
SET FOREIGN_KEY_CHECKS = 1;

-- -------------------------------------
-- 2. Staging table (mirrors CSV columns)
-- -------------------------------------
DROP TABLE IF EXISTS raw_match;

CREATE TABLE raw_match (
    `Div`   VARCHAR(10),
    `Date`  VARCHAR(20),
    HomeTeam VARCHAR(100),
    AwayTeam VARCHAR(100),

    FTHG TINYINT,
    FTAG TINYINT,
    FTR  VARCHAR(5),

    HTHG TINYINT,
    HTAG TINYINT,
    HTR  VARCHAR(5),

    Referee VARCHAR(100),

    HS  SMALLINT,
    `AS` SMALLINT,
    HST SMALLINT,
    AST SMALLINT,
    HF  SMALLINT,
    AF  SMALLINT,
    HC  SMALLINT,
    AC  SMALLINT,
    HY  SMALLINT,
    AY  SMALLINT,
    HR  SMALLINT,
    AR  SMALLINT,

    B365H DECIMAL(6,2),
    B365D DECIMAL(6,2),
    B365A DECIMAL(6,2)
);

-- =====================================================
-- Helper block (repeated per season):
--   - TRUNCATE raw_match
--   - LOAD DATA LOCAL INFILE 'CSV_PATH'
--   - INSERT team + referee
--   - INSERT into match
--   - INSERT into match_odds
-- =====================================================

-- ***************
-- SEASON 2020-2021
-- ***************

TRUNCATE TABLE raw_match;

LOAD DATA LOCAL INFILE '/home/coder/project/DBWT midterms/Data/Season 2020:2021.csv'
INTO TABLE raw_match
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
  `Div`, `Date`,
  HomeTeam, AwayTeam,
  FTHG, FTAG, FTR,
  HTHG, HTAG, HTR,
  Referee,
  HS, `AS`, HST, AST,
  HF, AF, HC, AC,
  HY, AY, HR, AR,
  B365H, B365D, B365A
);

-- teams & referees from this season
INSERT IGNORE INTO team (name)
SELECT DISTINCT HomeTeam FROM raw_match
UNION
SELECT DISTINCT AwayTeam FROM raw_match;

INSERT IGNORE INTO referee (name)
SELECT DISTINCT Referee
FROM raw_match
WHERE Referee IS NOT NULL AND Referee <> '';

-- matches
INSERT INTO `match` (
    league_id, season_id,
    match_date, match_time,
    home_team_id, away_team_id,
    full_time_home_goals, full_time_away_goals, full_time_result,
    half_time_home_goals, half_time_away_goals, half_time_result,
    referee_id,
    home_shots, away_shots,
    home_shots_on_target, away_shots_on_target,
    home_fouls, away_fouls,
    home_corners, away_corners,
    home_yellow_cards, away_yellow_cards,
    home_red_cards, away_red_cards,
    original_div_code
)
SELECT
    l.league_id,
    s.season_id,
    STR_TO_DATE(r.`Date`, '%d/%m/%Y'),
    NULL,
    ht.team_id,
    at.team_id,
    r.FTHG,
    r.FTAG,
    TRIM(r.FTR),
    r.HTHG,
    r.HTAG,
    CASE WHEN TRIM(r.HTR) IN ('H','D','A') THEN TRIM(r.HTR) ELSE NULL END,
    ref.referee_id,
    r.HS,
    r.`AS`,
    r.HST,
    r.AST,
    r.HF,
    r.AF,
    r.HC,
    r.AC,
    r.HY,
    r.AY,
    r.HR,
    r.AR,
    r.`Div`
FROM raw_match r
JOIN league l ON l.code = 'E0'
JOIN season s ON s.name = '2020-2021'
JOIN team ht ON ht.name = r.HomeTeam
JOIN team at ON at.name = r.AwayTeam
LEFT JOIN referee ref ON ref.name = r.Referee
WHERE TRIM(r.FTR) IN ('H','D','A');

-- odds
INSERT INTO match_odds (
    match_id, bookmaker_id,
    home_win_odds, draw_odds, away_win_odds
)
SELECT
    m.match_id,
    b.bookmaker_id,
    r.B365H, r.B365D, r.B365A
FROM raw_match r
JOIN league l ON l.code = 'E0'
JOIN season s ON s.name = '2020-2021'
JOIN team ht ON ht.name = r.HomeTeam
JOIN team at ON at.name = r.AwayTeam
JOIN `match` m
  ON m.league_id = l.league_id
 AND m.season_id = s.season_id
 AND m.home_team_id = ht.team_id
 AND m.away_team_id = at.team_id
 AND m.match_date = STR_TO_DATE(r.`Date`, '%d/%m/%Y')
JOIN bookmaker b ON b.code = 'B365';

-- ***************
-- SEASON 2021-2022
-- ***************

TRUNCATE TABLE raw_match;

LOAD DATA LOCAL INFILE '/home/coder/project/DBWT midterms/Data/Season 2021:2022.csv'
INTO TABLE raw_match
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
  `Div`, `Date`,
  HomeTeam, AwayTeam,
  FTHG, FTAG, FTR,
  HTHG, HTAG, HTR,
  Referee,
  HS, `AS`, HST, AST,
  HF, AF, HC, AC,
  HY, AY, HR, AR,
  B365H, B365D, B365A
);

INSERT IGNORE INTO team (name)
SELECT DISTINCT HomeTeam FROM raw_match
UNION
SELECT DISTINCT AwayTeam FROM raw_match;

INSERT IGNORE INTO referee (name)
SELECT DISTINCT Referee
FROM raw_match
WHERE Referee IS NOT NULL AND Referee <> '';

INSERT INTO `match` (
    league_id, season_id,
    match_date, match_time,
    home_team_id, away_team_id,
    full_time_home_goals, full_time_away_goals, full_time_result,
    half_time_home_goals, half_time_away_goals, half_time_result,
    referee_id,
    home_shots, away_shots,
    home_shots_on_target, away_shots_on_target,
    home_fouls, away_fouls,
    home_corners, away_corners,
    home_yellow_cards, away_yellow_cards,
    home_red_cards, away_red_cards,
    original_div_code
)
SELECT
    l.league_id,
    s.season_id,
    STR_TO_DATE(r.`Date`, '%d/%m/%Y'),
    NULL,
    ht.team_id,
    at.team_id,
    r.FTHG,
    r.FTAG,
    TRIM(r.FTR),
    r.HTHG,
    r.HTAG,
    CASE WHEN TRIM(r.HTR) IN ('H','D','A') THEN TRIM(r.HTR) ELSE NULL END,
    ref.referee_id,
    r.HS,
    r.`AS`,
    r.HST,
    r.AST,
    r.HF,
    r.AF,
    r.HC,
    r.AC,
    r.HY,
    r.AY,
    r.HR,
    r.AR,
    r.`Div`
FROM raw_match r
JOIN league l ON l.code = 'E0'
JOIN season s ON s.name = '2021-2022'
JOIN team ht ON ht.name = r.HomeTeam
JOIN team at ON at.name = r.AwayTeam
LEFT JOIN referee ref ON ref.name = r.Referee
WHERE TRIM(r.FTR) IN ('H','D','A');

INSERT INTO match_odds (
    match_id, bookmaker_id,
    home_win_odds, draw_odds, away_win_odds
)
SELECT
    m.match_id,
    b.bookmaker_id,
    r.B365H, r.B365D, r.B365A
FROM raw_match r
JOIN league l ON l.code = 'E0'
JOIN season s ON s.name = '2021-2022'
JOIN team ht ON ht.name = r.HomeTeam
JOIN team at ON at.name = r.AwayTeam
JOIN `match` m
  ON m.league_id = l.league_id
 AND m.season_id = s.season_id
 AND m.home_team_id = ht.team_id
 AND m.away_team_id = at.team_id
 AND m.match_date = STR_TO_DATE(r.`Date`, '%d/%m/%Y')
JOIN bookmaker b ON b.code = 'B365';

-- ***************
-- SEASON 2022-2023
-- ***************

TRUNCATE TABLE raw_match;

LOAD DATA LOCAL INFILE '/home/coder/project/DBWT midterms/Data/Season 2022:2023.csv'
INTO TABLE raw_match
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
  `Div`, `Date`,
  HomeTeam, AwayTeam,
  FTHG, FTAG, FTR,
  HTHG, HTAG, HTR,
  Referee,
  HS, `AS`, HST, AST,
  HF, AF, HC, AC,
  HY, AY, HR, AR,
  B365H, B365D, B365A
);

INSERT IGNORE INTO team (name)
SELECT DISTINCT HomeTeam FROM raw_match
UNION
SELECT DISTINCT AwayTeam FROM raw_match;

INSERT IGNORE INTO referee (name)
SELECT DISTINCT Referee
FROM raw_match
WHERE Referee IS NOT NULL AND Referee <> '';

INSERT INTO `match` (
    league_id, season_id,
    match_date, match_time,
    home_team_id, away_team_id,
    full_time_home_goals, full_time_away_goals, full_time_result,
    half_time_home_goals, half_time_away_goals, half_time_result,
    referee_id,
    home_shots, away_shots,
    home_shots_on_target, away_shots_on_target,
    home_fouls, away_fouls,
    home_corners, away_corners,
    home_yellow_cards, away_yellow_cards,
    home_red_cards, away_red_cards,
    original_div_code
)
SELECT
    l.league_id,
    s.season_id,
    STR_TO_DATE(r.`Date`, '%d/%m/%Y'),
    NULL,
    ht.team_id,
    at.team_id,
    r.FTHG,
    r.FTAG,
    TRIM(r.FTR),
    r.HTHG,
    r.HTAG,
    CASE WHEN TRIM(r.HTR) IN ('H','D','A') THEN TRIM(r.HTR) ELSE NULL END,
    ref.referee_id,
    r.HS,
    r.`AS`,
    r.HST,
    r.AST,
    r.HF,
    r.AF,
    r.HC,
    r.AC,
    r.HY,
    r.AY,
    r.HR,
    r.AR,
    r.`Div`
FROM raw_match r
JOIN league l ON l.code = 'E0'
JOIN season s ON s.name = '2022-2023'
JOIN team ht ON ht.name = r.HomeTeam
JOIN team at ON at.name = r.AwayTeam
LEFT JOIN referee ref ON ref.name = r.Referee
WHERE TRIM(r.FTR) IN ('H','D','A');

INSERT INTO match_odds (
    match_id, bookmaker_id,
    home_win_odds, draw_odds, away_win_odds
)
SELECT
    m.match_id,
    b.bookmaker_id,
    r.B365H, r.B365D, r.B365A
FROM raw_match r
JOIN league l ON l.code = 'E0'
JOIN season s ON s.name = '2022-2023'
JOIN team ht ON ht.name = r.HomeTeam
JOIN team at ON at.name = r.AwayTeam
JOIN `match` m
  ON m.league_id = l.league_id
 AND m.season_id = s.season_id
 AND m.home_team_id = ht.team_id
 AND m.away_team_id = at.team_id
 AND m.match_date = STR_TO_DATE(r.`Date`, '%d/%m/%Y')
JOIN bookmaker b ON b.code = 'B365';

-- ***************
-- SEASON 2023-2024
-- ***************

TRUNCATE TABLE raw_match;

LOAD DATA LOCAL INFILE '/home/coder/project/DBWT midterms/Data/Season 2023:2024.csv'
INTO TABLE raw_match
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
  `Div`, `Date`,
  HomeTeam, AwayTeam,
  FTHG, FTAG, FTR,
  HTHG, HTAG, HTR,
  Referee,
  HS, `AS`, HST, AST,
  HF, AF, HC, AC,
  HY, AY, HR, AR,
  B365H, B365D, B365A
);

INSERT IGNORE INTO team (name)
SELECT DISTINCT HomeTeam FROM raw_match
UNION
SELECT DISTINCT AwayTeam FROM raw_match;

INSERT IGNORE INTO referee (name)
SELECT DISTINCT Referee
FROM raw_match
WHERE Referee IS NOT NULL AND Referee <> '';

INSERT INTO `match` (
    league_id, season_id,
    match_date, match_time,
    home_team_id, away_team_id,
    full_time_home_goals, full_time_away_goals, full_time_result,
    half_time_home_goals, half_time_away_goals, half_time_result,
    referee_id,
    home_shots, away_shots,
    home_shots_on_target, away_shots_on_target,
    home_fouls, away_fouls,
    home_corners, away_corners,
    home_yellow_cards, away_yellow_cards,
    home_red_cards, away_red_cards,
    original_div_code
)
SELECT
    l.league_id,
    s.season_id,
    STR_TO_DATE(r.`Date`, '%d/%m/%Y'),
    NULL,
    ht.team_id,
    at.team_id,
    r.FTHG,
    r.FTAG,
    TRIM(r.FTR),
    r.HTHG,
    r.HTAG,
    CASE WHEN TRIM(r.HTR) IN ('H','D','A') THEN TRIM(r.HTR) ELSE NULL END,
    ref.referee_id,
    r.HS,
    r.`AS`,
    r.HST,
    r.AST,
    r.HF,
    r.AF,
    r.HC,
    r.AC,
    r.HY,
    r.AY,
    r.HR,
    r.AR,
    r.`Div`
FROM raw_match r
JOIN league l ON l.code = 'E0'
JOIN season s ON s.name = '2023-2024'
JOIN team ht ON ht.name = r.HomeTeam
JOIN team at ON at.name = r.AwayTeam
LEFT JOIN referee ref ON ref.name = r.Referee
WHERE TRIM(r.FTR) IN ('H','D','A');

INSERT INTO match_odds (
    match_id, bookmaker_id,
    home_win_odds, draw_odds, away_win_odds
)
SELECT
    m.match_id,
    b.bookmaker_id,
    r.B365H, r.B365D, r.B365A
FROM raw_match r
JOIN league l ON l.code = 'E0'
JOIN season s ON s.name = '2023-2024'
JOIN team ht ON ht.name = r.HomeTeam
JOIN team at ON at.name = r.AwayTeam
JOIN `match` m
  ON m.league_id = l.league_id
 AND m.season_id = s.season_id
 AND m.home_team_id = ht.team_id
 AND m.away_team_id = at.team_id
 AND m.match_date = STR_TO_DATE(r.`Date`, '%d/%m/%Y')
JOIN bookmaker b ON b.code = 'B365';

-- ***************
-- SEASON 2024-2025
-- ***************

TRUNCATE TABLE raw_match;

LOAD DATA LOCAL INFILE '/home/coder/project/DBWT midterms/Data/Season 2024:2025.csv'
INTO TABLE raw_match
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
  `Div`, `Date`,
  HomeTeam, AwayTeam,
  FTHG, FTAG, FTR,
  HTHG, HTAG, HTR,
  Referee,
  HS, `AS`, HST, AST,
  HF, AF, HC, AC,
  HY, AY, HR, AR,
  B365H, B365D, B365A
);

INSERT IGNORE INTO team (name)
SELECT DISTINCT HomeTeam FROM raw_match
UNION
SELECT DISTINCT AwayTeam FROM raw_match;

INSERT IGNORE INTO referee (name)
SELECT DISTINCT Referee
FROM raw_match
WHERE Referee IS NOT NULL AND Referee <> '';

INSERT INTO `match` (
    league_id, season_id,
    match_date, match_time,
    home_team_id, away_team_id,
    full_time_home_goals, full_time_away_goals, full_time_result,
    half_time_home_goals, half_time_away_goals, half_time_result,
    referee_id,
    home_shots, away_shots,
    home_shots_on_target, away_shots_on_target,
    home_fouls, away_fouls,
    home_corners, away_corners,
    home_yellow_cards, away_yellow_cards,
    home_red_cards, away_red_cards,
    original_div_code
)
SELECT
    l.league_id,
    s.season_id,
    STR_TO_DATE(r.`Date`, '%d/%m/%Y'),
    NULL,
    ht.team_id,
    at.team_id,
    r.FTHG,
    r.FTAG,
    TRIM(r.FTR),
    r.HTHG,
    r.HTAG,
    CASE WHEN TRIM(r.HTR) IN ('H','D','A') THEN TRIM(r.HTR) ELSE NULL END,
    ref.referee_id,
    r.HS,
    r.`AS`,
    r.HST,
    r.AST,
    r.HF,
    r.AF,
    r.HC,
    r.AC,
    r.HY,
    r.AY,
    r.HR,
    r.AR,
    r.`Div`
FROM raw_match r
JOIN league l ON l.code = 'E0'
JOIN season s ON s.name = '2024-2025'
JOIN team ht ON ht.name = r.HomeTeam
JOIN team at ON at.name = r.AwayTeam
LEFT JOIN referee ref ON ref.name = r.Referee
WHERE TRIM(r.FTR) IN ('H','D','A');

INSERT INTO match_odds (
    match_id, bookmaker_id,
    home_win_odds, draw_odds, away_win_odds
)
SELECT
    m.match_id,
    b.bookmaker_id,
    r.B365H, r.B365D, r.B365A
FROM raw_match r
JOIN league l ON l.code = 'E0'
JOIN season s ON s.name = '2024-2025'
JOIN team ht ON ht.name = r.HomeTeam
JOIN team at ON at.name = r.AwayTeam
JOIN `match` m
  ON m.league_id = l.league_id
 AND m.season_id = s.season_id
 AND m.home_team_id = ht.team_id
 AND m.away_team_id = at.team_id
 AND m.match_date = STR_TO_DATE(r.`Date`, '%d/%m/%Y')
JOIN bookmaker b ON b.code = 'B365';

-- END OF SCRIPT
