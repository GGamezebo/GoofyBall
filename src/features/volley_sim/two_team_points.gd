class_name TwoTeamPoints
extends RefCounted

## Scoring rule for two teams: losing a rally gives the other team a point, first to
## `win_score` wins. (Three or more teams will get `MultiZoneLives`.)


static func rally_winner(losing_team: int) -> int:
	return 1 - losing_team


## Winning team index, or -1 while nobody has reached `win_score`.
static func match_winner(scores: Array, win_score: int) -> int:
	for team in scores.size():
		if int(scores[team]) >= win_score:
			return team
	return -1
