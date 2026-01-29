-- ============================================================
-- QUESTION 1:
-- Which teams demonstrate the highest long-term consistency across five seasons?
-- (Consistency measured using points per season variation + avg points)
-- ============================================================

WITH team_points AS (
    SELECT 
        t.team_id,
        t.name AS team_name,
        s.name AS season,
        SUM(
            CASE 
                WHEN m.home_team_id = t.team_id AND m.full_time_result = 'H' THEN 3
                WHEN m.away_team_id = t.team_id AND m.full_time_result = 'A' THEN 3
                WHEN m.full_time_result = 'D' THEN 1
                ELSE 0
            END
        ) AS total_points
    FROM `match` m
    JOIN season s ON m.season_id = s.season_id
    JOIN team t ON t.team_id IN (m.home_team_id, m.away_team_id)
    GROUP BY t.team_id, t.name, s.name
),
team_stats AS (
    SELECT 
        team_name,
        AVG(total_points) AS avg_points,
        STDDEV(total_points) AS variation,
        COUNT(*) AS seasons_played
    FROM team_points
    GROUP BY team_name
    HAVING COUNT(*) = 5
)
SELECT 
    team_name,
    avg_points,
    variation,
    (avg_points / (1 + variation)) AS consistency_score
FROM team_stats
ORDER BY consistency_score DESC;


-- ============================================================
-- QUESTION 2:
-- Which teams significantly over- or under-perform relative to bookmaker expectations across five seasons?
-- (Compare actual points vs bookmaker-implied expected points from odds)
-- ============================================================

WITH match_probs AS (
    SELECT
        m.match_id,
        m.season_id,
        s.name AS season_name,
        m.home_team_id,
        m.away_team_id,
        m.full_time_result,
        mo.home_win_odds,
        mo.draw_odds,
        mo.away_win_odds,
        (1.0 / mo.home_win_odds) AS inv_h,
        (1.0 / mo.draw_odds) AS inv_d,
        (1.0 / mo.away_win_odds) AS inv_a
    FROM `match` m
    JOIN match_odds mo ON mo.match_id = m.match_id
    JOIN season s ON s.season_id = m.season_id
    JOIN bookmaker b ON b.bookmaker_id = mo.bookmaker_id
    WHERE b.code = 'B365'
      AND mo.home_win_odds IS NOT NULL
      AND mo.draw_odds IS NOT NULL
      AND mo.away_win_odds IS NOT NULL
      AND mo.home_win_odds  > 0
      AND mo.draw_odds      > 0
      AND mo.away_win_odds  > 0
),
match_probs_norm AS (
    SELECT
        mp.*,
        (mp.inv_h + mp.inv_d + mp.inv_a) AS denom,
        (mp.inv_h / (mp.inv_h + mp.inv_d + mp.inv_a)) AS p_home,
        (mp.inv_d / (mp.inv_h + mp.inv_d + mp.inv_a)) AS p_draw,
        (mp.inv_a / (mp.inv_h + mp.inv_d + mp.inv_a)) AS p_away
    FROM match_probs mp
),
team_match_points AS (
    -- home team perspective
    SELECT
        mpn.season_id,
        mpn.season_name,
        t_home.team_id,
        t_home.name AS team_name,
        mpn.match_id,
        (3 * mpn.p_home + 1 * mpn.p_draw) AS expected_points,
        CASE
            WHEN mpn.full_time_result = 'H' THEN 3
            WHEN mpn.full_time_result = 'D' THEN 1
            ELSE 0
        END AS actual_points
    FROM match_probs_norm mpn
    JOIN team t_home ON t_home.team_id = mpn.home_team_id

    UNION ALL

    -- away team perspective
    SELECT
        mpn.season_id,
        mpn.season_name,
        t_away.team_id,
        t_away.name AS team_name,
        mpn.match_id,
        (3 * mpn.p_away + 1 * mpn.p_draw) AS expected_points,
        CASE
            WHEN mpn.full_time_result = 'A' THEN 3
            WHEN mpn.full_time_result = 'D' THEN 1
            ELSE 0
        END AS actual_points
    FROM match_probs_norm mpn
    JOIN team t_away ON t_away.team_id = mpn.away_team_id
)
SELECT
    tmp.team_name,
    COUNT(*) AS matches_considered,
    COUNT(DISTINCT tmp.season_id) AS seasons_covered,
    ROUND(SUM(tmp.actual_points), 2) AS total_actual_points,
    ROUND(SUM(tmp.expected_points), 2) AS total_expected_points,
    ROUND(SUM(tmp.actual_points) / COUNT(*), 3) AS avg_actual_points_per_game,
    ROUND(SUM(tmp.expected_points) / COUNT(*), 3) AS avg_expected_points_per_game,
    ROUND(SUM(tmp.actual_points) - SUM(tmp.expected_points), 3) AS points_over_expected,
    ROUND(
        (SUM(tmp.actual_points) - SUM(tmp.expected_points)) / COUNT(*),
        3
    ) AS points_over_expected_per_game
FROM team_match_points tmp
GROUP BY tmp.team_id, tmp.team_name
HAVING COUNT(DISTINCT tmp.season_id) = 5
ORDER BY points_over_expected_per_game DESC;


-- ============================================================
-- QUESTION 3:
-- Which teams are most effective at turning losing half-time positions into full-time results?
-- (Losing at HT -> WIN / DRAW / NON-LOSS by FT)
-- ============================================================

WITH losing_positions AS (
    -- Home team losing at half-time
    SELECT
        m.match_id,
        s.name AS season_name,
        th.team_id,
        th.name AS team_name,
        'H' AS side,
        m.full_time_result,
        1 AS losing_ht,
        CASE WHEN m.full_time_result = 'H' THEN 1 ELSE 0 END AS turned_to_win,
        CASE WHEN m.full_time_result = 'D' THEN 1 ELSE 0 END AS turned_to_draw,
        CASE WHEN m.full_time_result IN ('H','D') THEN 1 ELSE 0 END AS turned_to_non_loss
    FROM `match` m
    JOIN season s ON s.season_id = m.season_id
    JOIN team th ON th.team_id = m.home_team_id
    WHERE m.half_time_result = 'A'

    UNION ALL

    -- Away team losing at half-time
    SELECT
        m.match_id,
        s.name AS season_name,
        ta.team_id,
        ta.name AS team_name,
        'A' AS side,
        m.full_time_result,
        1 AS losing_ht,
        CASE WHEN m.full_time_result = 'A' THEN 1 ELSE 0 END AS turned_to_win,
        CASE WHEN m.full_time_result = 'D' THEN 1 ELSE 0 END AS turned_to_draw,
        CASE WHEN m.full_time_result IN ('A','D') THEN 1 ELSE 0 END AS turned_to_non_loss
    FROM `match` m
    JOIN season s ON s.season_id = m.season_id
    JOIN team ta ON ta.team_id = m.away_team_id
    WHERE m.half_time_result = 'H'
)
SELECT
    lp.team_name,
    COUNT(*) AS losing_ht_games,
    SUM(lp.turned_to_win)       AS full_comebacks_to_win,
    SUM(lp.turned_to_draw)      AS comebacks_to_draw,
    SUM(lp.turned_to_non_loss)  AS comebacks_to_non_loss,
    ROUND(SUM(lp.turned_to_win) * 100.0 / COUNT(*), 2)      AS win_comeback_pct,
    ROUND(SUM(lp.turned_to_draw) * 100.0 / COUNT(*), 2)     AS draw_comeback_pct,
    ROUND(SUM(lp.turned_to_non_loss) * 100.0 / COUNT(*), 2) AS non_loss_comeback_pct
FROM losing_positions lp
GROUP BY lp.team_id, lp.team_name
HAVING COUNT(*) >= 5
ORDER BY win_comeback_pct DESC, non_loss_comeback_pct DESC;


-- ============================================================
-- QUESTION 4:
-- Do teams with more shots on target convert pressure into wins or do inefficiencies appear?
-- (Pressure = more shots on target than opponent)
-- ============================================================

WITH shot_diff AS (
    SELECT
        m.match_id,
        m.season_id,
        m.home_team_id,
        m.away_team_id,
        m.home_shots_on_target,
        m.away_shots_on_target,
        m.full_time_result,
        CASE
            WHEN m.home_shots_on_target > m.away_shots_on_target THEN 'H'
            WHEN m.away_shots_on_target > m.home_shots_on_target THEN 'A'
            ELSE 'T'
        END AS pressure_side
    FROM `match` m
),
pressure_team_view AS (
    SELECT
        CASE 
            WHEN sd.pressure_side = 'H' THEN sd.home_team_id
            WHEN sd.pressure_side = 'A' THEN sd.away_team_id
        END AS team_id,
        sd.full_time_result,
        sd.pressure_side
    FROM shot_diff sd
    WHERE sd.pressure_side <> 'T'
)
SELECT
    t.name AS team_name,
    COUNT(*) AS matches_with_pressure,
    SUM(
        CASE 
            WHEN (ptv.pressure_side = 'H' AND ptv.full_time_result = 'H')
              OR (ptv.pressure_side = 'A' AND ptv.full_time_result = 'A')
            THEN 1 ELSE 0 END
    ) AS wins_with_pressure,
    SUM(CASE WHEN ptv.full_time_result = 'D' THEN 1 ELSE 0 END) AS draws_with_pressure,
    SUM(
        CASE 
            WHEN ptv.full_time_result IN ('H','A')
             AND NOT (
                (ptv.pressure_side = 'H' AND ptv.full_time_result = 'H') OR
                (ptv.pressure_side = 'A' AND ptv.full_time_result = 'A')
             )
            THEN 1 ELSE 0 END
    ) AS losses_despite_pressure,
    ROUND(
        SUM(
            CASE 
                WHEN (ptv.pressure_side = 'H' AND ptv.full_time_result = 'H')
                  OR (ptv.pressure_side = 'A' AND ptv.full_time_result = 'A')
                THEN 1 ELSE 0 END
        ) * 100.0 / COUNT(*), 2
    ) AS win_rate_with_pressure_pct,
    ROUND(SUM(CASE WHEN ptv.full_time_result = 'D' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)
        AS draw_rate_with_pressure_pct,
    ROUND(
        SUM(
            CASE 
                WHEN ptv.full_time_result IN ('H','A')
                 AND NOT (
                    (ptv.pressure_side = 'H' AND ptv.full_time_result = 'H') OR
                    (ptv.pressure_side = 'A' AND ptv.full_time_result = 'A')
                 )
                THEN 1 ELSE 0 END
        ) * 100.0 / COUNT(*), 2
    ) AS loss_rate_despite_pressure_pct
FROM pressure_team_view ptv
JOIN team t ON t.team_id = ptv.team_id
GROUP BY ptv.team_id, t.name
HAVING COUNT(*) >= 10
ORDER BY win_rate_with_pressure_pct DESC, loss_rate_despite_pressure_pct ASC;


-- ============================================================
-- QUESTION 5:
-- How have scoring patterns evolved across five seasons overall,
-- by half, and by home vs away teams and do these trends suggest tactical changes?
-- (Outputs overall goals, home vs away goals, first vs second half goals, volatility)
-- ============================================================

USE football_analysis;

SELECT
    s.name AS season_name,
    COUNT(*) AS matches,
    ROUND(AVG(m.full_time_home_goals + m.full_time_away_goals), 2) AS avg_total_goals,
    ROUND(AVG(m.full_time_home_goals), 2) AS avg_home_goals,
    ROUND(AVG(m.full_time_away_goals), 2) AS avg_away_goals,
    ROUND(
        100.0 * SUM(m.full_time_home_goals) /
        NULLIF(SUM(m.full_time_home_goals + m.full_time_away_goals), 0),
        2
    ) AS pct_goals_by_home_team,
    ROUND(AVG(m.half_time_home_goals + m.half_time_away_goals), 2) AS avg_first_half_goals,
    ROUND(
        AVG(
            (m.full_time_home_goals + m.full_time_away_goals) -
            (m.half_time_home_goals + m.half_time_away_goals)
        ), 2
    ) AS avg_second_half_goals,
    ROUND(
        100.0 * SUM(
            (m.full_time_home_goals + m.full_time_away_goals) -
            (m.half_time_home_goals + m.half_time_away_goals)
        ) /
        NULLIF(SUM(m.full_time_home_goals + m.full_time_away_goals), 0),
        2
    ) AS pct_goals_in_second_half,
    ROUND(STDDEV_POP(m.full_time_home_goals + m.full_time_away_goals), 2) AS goal_variability
FROM `match` m
JOIN season s ON s.season_id = m.season_id
GROUP BY s.name
ORDER BY s.name;


-- ============================================================
-- QUESTION 6:
-- Are bookmakers becoming more accurate at predicting match outcomes over time?
-- (Season-level accuracy and season-to-season change, overall + medium confidence)
-- ============================================================

USE football_analysis;

WITH bookmaker_predictions AS (
    SELECT
        s.name AS season_name,
        m.full_time_result AS actual_result,
        CASE
            WHEN mo.home_win_odds <= mo.draw_odds
             AND mo.home_win_odds <= mo.away_win_odds THEN 'H'
            WHEN mo.draw_odds <= mo.home_win_odds
             AND mo.draw_odds <= mo.away_win_odds THEN 'D'
            ELSE 'A'
        END AS predicted_result,
        LEAST(mo.home_win_odds, mo.draw_odds, mo.away_win_odds) AS confidence_odds
    FROM match_odds mo
    JOIN `match` m ON m.match_id = mo.match_id
    JOIN season s  ON s.season_id = m.season_id
),
classified AS (
    SELECT
        season_name,
        CASE WHEN predicted_result = actual_result THEN 1 ELSE 0 END AS correct_prediction,
        CASE
            WHEN confidence_odds <= 1.60 THEN 'high'
            WHEN confidence_odds <= 2.20 THEN 'medium'
            ELSE 'low'
        END AS confidence_level
    FROM bookmaker_predictions
),
season_metrics AS (
    SELECT
        season_name,
        ROUND(SUM(correct_prediction) * 100.0 / COUNT(*), 2) AS overall_prediction_accuracy_pct,
        SUM(confidence_level = 'medium') AS medium_confidence_match_count,
        ROUND(
            SUM(CASE WHEN confidence_level = 'medium' THEN correct_prediction ELSE 0 END) * 100.0 /
            NULLIF(SUM(confidence_level = 'medium'), 0),
            2
        ) AS medium_confidence_accuracy_pct
    FROM classified
    GROUP BY season_name
),
final AS (
    SELECT
        season_name,
        overall_prediction_accuracy_pct,
        ROUND(
            overall_prediction_accuracy_pct
            - LAG(overall_prediction_accuracy_pct) OVER (ORDER BY season_name),
            2
        ) AS overall_accuracy_change_pp,
        medium_confidence_match_count,
        medium_confidence_accuracy_pct,
        ROUND(
            medium_confidence_accuracy_pct
            - LAG(medium_confidence_accuracy_pct) OVER (ORDER BY season_name),
            2
        ) AS medium_confidence_accuracy_change_pp
    FROM season_metrics
)
SELECT
    season_name,
    overall_prediction_accuracy_pct,
    overall_accuracy_change_pp,
    medium_confidence_match_count,
    medium_confidence_accuracy_pct,
    medium_confidence_accuracy_change_pp
FROM final
ORDER BY season_name;


-- ============================================================
-- QUESTION 7A:
-- Is aggressive play (fouls and cards) linked to success, or does it harm performance?
-- (Team-level averages across all matches: aggression index vs points/goal diff)
-- ============================================================

USE football_analysis;

WITH team_match AS (
    SELECT
        m.season_id,
        m.match_id,
        m.home_team_id AS team_id,
        m.home_fouls         AS fouls,
        m.home_yellow_cards  AS yellows,
        m.home_red_cards     AS reds,
        (m.home_fouls + 3*m.home_yellow_cards + 10*m.home_red_cards) AS aggression_index,
        CASE
            WHEN m.full_time_result = 'H' THEN 3
            WHEN m.full_time_result = 'D' THEN 1
            ELSE 0
        END AS points,
        (m.full_time_home_goals - m.full_time_away_goals) AS goal_diff
    FROM `match` m

    UNION ALL

    SELECT
        m.season_id,
        m.match_id,
        m.away_team_id AS team_id,
        m.away_fouls         AS fouls,
        m.away_yellow_cards  AS yellows,
        m.away_red_cards     AS reds,
        (m.away_fouls + 3*m.away_yellow_cards + 10*m.away_red_cards) AS aggression_index,
        CASE
            WHEN m.full_time_result = 'A' THEN 3
            WHEN m.full_time_result = 'D' THEN 1
            ELSE 0
        END AS points,
        (m.full_time_away_goals - m.full_time_home_goals) AS goal_diff
    FROM `match` m
),
team_summary AS (
    SELECT
        t.team_id,
        t.name AS team_name,
        COUNT(*) AS matches,
        ROUND(AVG(points), 3) AS avg_points_per_match,
        ROUND(AVG(goal_diff), 3) AS avg_goal_diff_per_match,
        ROUND(AVG(fouls), 2)   AS avg_fouls_per_match,
        ROUND(AVG(yellows), 2) AS avg_yellows_per_match,
        ROUND(AVG(reds), 3)    AS avg_reds_per_match,
        ROUND(AVG(aggression_index), 2) AS avg_aggression_index
    FROM team_match tm
    JOIN team t ON t.team_id = tm.team_id
    GROUP BY t.team_id, t.name
)
SELECT
    team_name,
    matches,
    avg_aggression_index,
    avg_fouls_per_match,
    avg_yellows_per_match,
    avg_reds_per_match,
    avg_points_per_match,
    avg_goal_diff_per_match
FROM team_summary
WHERE matches >= 190
ORDER BY avg_aggression_index DESC, avg_points_per_match DESC;


-- ============================================================
-- QUESTION 7B:
-- Is aggressive play (fouls and cards) linked to success, or does it harm performance?
-- (League-wide view: group matches into low/medium/high aggression and compare outcomes)
-- ============================================================

USE football_analysis;

WITH team_match AS (
    SELECT
        m.season_id,
        m.match_id,
        m.home_team_id AS team_id,
        (m.home_fouls + 3*m.home_yellow_cards + 10*m.home_red_cards) AS aggression_index,
        CASE
            WHEN m.full_time_result = 'H' THEN 3
            WHEN m.full_time_result = 'D' THEN 1
            ELSE 0
        END AS points,
        (m.full_time_home_goals - m.full_time_away_goals) AS goal_diff
    FROM `match` m

    UNION ALL

    SELECT
        m.season_id,
        m.match_id,
        m.away_team_id AS team_id,
        (m.away_fouls + 3*m.away_yellow_cards + 10*m.away_red_cards) AS aggression_index,
        CASE
            WHEN m.full_time_result = 'A' THEN 3
            WHEN m.full_time_result = 'D' THEN 1
            ELSE 0
        END AS points,
        (m.full_time_away_goals - m.full_time_home_goals) AS goal_diff
    FROM `match` m
),
banded AS (
    SELECT
        *,
        NTILE(3) OVER (ORDER BY aggression_index) AS aggression_tercile
    FROM team_match
)
SELECT
    CASE aggression_tercile
        WHEN 1 THEN 'Low aggression'
        WHEN 2 THEN 'Medium aggression'
        WHEN 3 THEN 'High aggression'
    END AS aggression_band,
    COUNT(*) AS team_match_rows,
    ROUND(AVG(aggression_index), 2) AS avg_aggression_index,
    ROUND(AVG(points), 3) AS avg_points_per_match,
    ROUND(AVG(goal_diff), 3) AS avg_goal_diff_per_match,
    ROUND(100.0 * AVG(points = 3), 2) AS win_rate_pct,
    ROUND(100.0 * AVG(points = 1), 2) AS draw_rate_pct,
    ROUND(100.0 * AVG(points = 0), 2) AS loss_rate_pct
FROM banded
GROUP BY aggression_tercile
ORDER BY aggression_tercile;


-- ============================================================
-- QUESTION 8a:
-- Do certain referees consistently award more cards, and does this influence match outcomes?
-- ============================================================
WITH ref_match AS (
  SELECT
    m.referee_id,
    m.season_id,
    (COALESCE(m.home_yellow_cards,0) + COALESCE(m.away_yellow_cards,0)) AS yellows_in_match,
    (COALESCE(m.home_red_cards,0)    + COALESCE(m.away_red_cards,0))    AS reds_in_match
  FROM `match` m
  WHERE m.referee_id IS NOT NULL
),

ref_season AS (
  SELECT
    referee_id,
    season_id,
    COUNT(*) AS matches_officiated,
    AVG(yellows_in_match) AS avg_yellows_per_match,
    AVG(reds_in_match)    AS avg_reds_per_match
  FROM ref_match
  GROUP BY referee_id, season_id
),

ref_overall AS (
  SELECT
    referee_id,
    SUM(matches_officiated) AS total_matches,
    COUNT(DISTINCT season_id) AS seasons_covered,

    AVG(avg_yellows_per_match) AS avg_yellows,
    STDDEV_POP(avg_yellows_per_match) AS yellows_stddev,

    AVG(avg_reds_per_match) AS avg_reds,
    STDDEV_POP(avg_reds_per_match) AS reds_stddev
  FROM ref_season
  GROUP BY referee_id
),

ref_extremes AS (
  SELECT
    referee_id,
    MIN(yellows_in_match) AS min_yellows_in_a_match,
    MAX(yellows_in_match) AS max_yellows_in_a_match,
    MIN(reds_in_match)    AS min_reds_in_a_match,
    MAX(reds_in_match)    AS max_reds_in_a_match
  FROM ref_match
  GROUP BY referee_id
)

SELECT
  r.name AS referee_name,
  ro.total_matches,
  ro.seasons_covered,

  ROUND(ro.avg_yellows, 3) AS avg_yellow_cards_per_match,
  ROUND(ro.yellows_stddev, 3) AS yellow_consistency_stddev,
  re.min_yellows_in_a_match,
  re.max_yellows_in_a_match,

  ROUND(ro.avg_reds, 3) AS avg_red_cards_per_match,
  ROUND(ro.reds_stddev, 3) AS red_consistency_stddev,
  re.min_reds_in_a_match,
  re.max_reds_in_a_match

FROM ref_overall ro
JOIN ref_extremes re ON re.referee_id = ro.referee_id
JOIN referee r ON r.referee_id = ro.referee_id
ORDER BY avg_yellow_cards_per_match DESC;

-- ============================================================
-- QUESTION 8b:
-- Do certain referees consistently award more cards, and does this influence match outcomes?
-- ============================================================

WITH ref_avg AS (
  SELECT
    m.referee_id,
    AVG(
      (COALESCE(m.home_yellow_cards,0) + COALESCE(m.away_yellow_cards,0)) +
      2*(COALESCE(m.home_red_cards,0)    + COALESCE(m.away_red_cards,0))
    ) AS ref_avg_weighted_cards,
    COUNT(*) AS ref_match_count
  FROM `match` m
  WHERE m.referee_id IS NOT NULL
  GROUP BY m.referee_id
  HAVING COUNT(*) >= 30
),
ranked AS (
  SELECT
    referee_id,
    ref_avg_weighted_cards,
    ref_match_count,
    NTILE(3) OVER (ORDER BY ref_avg_weighted_cards) AS card_intensity_tile
  FROM ref_avg
),
match_labeled AS (
  SELECT
    m.match_id,
    m.full_time_result,
    r.card_intensity_tile
  FROM `match` m
  JOIN ranked r ON r.referee_id = m.referee_id
)
SELECT
  CASE card_intensity_tile
    WHEN 1 THEN 'LOW_CARD_REFEREES'
    WHEN 2 THEN 'MEDIUM_CARD_REFEREES'
    WHEN 3 THEN 'HIGH_CARD_REFEREES'
  END AS referee_group,
  COUNT(*) AS matches,
  ROUND(100 * AVG(full_time_result = 'H'), 2) AS home_win_pct,
  ROUND(100 * AVG(full_time_result = 'D'), 2) AS draw_pct,
  ROUND(100 * AVG(full_time_result = 'A'), 2) AS away_win_pct
FROM match_labeled
GROUP BY card_intensity_tile
ORDER BY card_intensity_tile;
