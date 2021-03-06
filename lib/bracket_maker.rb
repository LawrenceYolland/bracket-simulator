
Challonge::API.username = Access.username
Challonge::API.key = Access.api_key

t = Challonge::Tournament.new
t.name = 'Stabley Cup 6001'
t.url = SecureRandom.hex(10) # randomly generates a 10 character string
 
t.tournament_type = 'single elimination'
t.save

url = "https://api.challonge.com/v1/tournaments/" + t.id.to_s + "/participants/bulk_add.json"

cli = CommandLineInterface.new
player_team, teams = cli.team_hash
rounds = Round.new(t, player_team)

Player.all.each do |player|
    player.series_goals = 0
    player.save 
end

Team.all.each do |team|
    team.wins = 0
    team.losses = 0
    team.save 
end

teams["api_key"] = Challonge::API.key 
RestClient.post(url, teams)

t.start! # t.post(:start)

#~~~~~~RUN SERIES AND SUBMIT MATCHES ~~~~~~~~~~~~~~~#
def update_matches(t, i)
    
    m = t.matches[i]

    assign_results = AssignResults.new

    team1_id = assign_results.team_1_id(m)
    team2_id = assign_results.team_2_id(m)

    player1_list = assign_results.get_player_list(team1_id)
    player2_list = assign_results.get_player_list(team2_id)

    scores = assign_results.sim_playoff_series(m) # defined in sim_series
    m.scores_csv = scores.join(",")

    # randomly assign team 1 players some goals
    assign_results.assign_goals(scores, team1_id, team1_id, player1_list)
    # randomly assign team 2 players some goals
    assign_results.assign_goals(scores, team2_id, team1_id, player2_list)

    player1_list.each { |p| p.save}
    player2_list.each { |p| p.save}

    t1_wins, t2_wins = assign_results.win_tally(scores)

    assign_results.give_win(team1_id, t1_wins, scores)
    assign_results.give_win(team2_id, t2_wins, scores)

    team1 = assign_results.get_team(team1_id)
    team2 = assign_results.get_team(team2_id)

    team1.each { |wl| wl.save}
    team2.each { |wl| wl.save}

    assign_results.gpg(team1_id)
    assign_results.gpg(team2_id)

    assign_results.chips if i == 14

    m
end

rounds.run_round


