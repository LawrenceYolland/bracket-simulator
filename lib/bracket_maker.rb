
require_relative '../config/environment.rb'

cli = CommandLineInterface.new

Challonge::API.username = Access.username
Challonge::API.key = Access.api_key

t = Challonge::Tournament.new
t.name = 'Stabley Cup 6000'
t.url = SecureRandom.hex(10) # randomly generates a 10 character string
t.tournament_type = 'single elimination'
t.save


Player.all.each do |player|
    player.series_goals = 0
    player.save 
end
# Player.all.each do |player|
#     player.total_goals = 0
#     player.save 
# end
# binding.pry
url = "https://api.challonge.com/v1/tournaments/" + t.id.to_s + "/participants/bulk_add.json"
teams = cli.team_hash

def player_team
    prompt = TTY::Prompt.new
    player_team = prompt.multi_select("Select your team:", teams)
    player_team
end

teams["api_key"] = Challonge::API.key 
RestClient.post(url, teams)
t.start! # t.post(:start)

#~~~~~~~~~~~~~~~~~RANDOMISE SERIES SCORES~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
def sim_playoff_series(m)
    score = []
    ot_options = [1,-1]
    until [bool_count(score, true), bool_count(score, false)].any?(4)
        total_goals_possible = rand(1..10) #10
        team_1_goals = rand(total_goals_possible)
        team_2_goals = (total_goals_possible-team_1_goals)        
        ot = rand(1)
        team_1_goals == team_2_goals ? team_1_goals+=ot_options[ot] : team_1_goals # overtime 
        score << "#{team_1_goals}-#{team_2_goals}"
    end
    if bool_count(score, true) > bool_count(score, false)
        m.winner_id = m.player1_id 
    else 
        m.winner_id = m.player2_id 
    end
    # score_csv = score
    score
end

def score_tally(score)
    score.collect {|s| s[0]>s[2]}
end

def bool_count(score, bool)
    score_tally(score).count(bool)
end
# ~~~~~~~~~ Assign goals to players ~~~~~~~~~~~~~~~~#
# score = ["6-1","3-2","1-2","5-1","4-5","4-3"]

# m.player1.name
# binding.pry
# class AssignGoals
#     def team_1_id(m)
#         Team.all.find_by(name: m.player1.name).id
#     end

#     def team_2_id(m)
#         Team.all.find_by(name: m.player2.name).id
#     end

#     def get_player_list(team_x_id)
#         Player.all.select { |p| p.team_id == team_x_id}
#     end

#     def give_goals(player, goal_assigner)
#         player.series_goals += goal_assigner
#         player.total_goals += goal_assigner
#     end

#     def player_goal_calculator(player_list, current_goals)
#         until current_goals == 0
#             goal_assigner = rand(1..current_goals)
#             current_goals -= goal_assigner
#             player = player_list[rand(4)]
#             give_goals(player, goal_assigner)
#         end
#     end

#     def assign_goals(scores, team_id, team_1_id, player_list)
#         team_id == team_1_id ? n = 0 : n = 2
#         current_goals = scores.sum { |s| s[n].to_i}
#         player_goal_calculator(player_list, current_goals)
#     end
# end
#~~~~~~~~~~~~~~~  RUN SERIES AND SUBMIT MATCHES ~~~~~~~~~~~~~~~#
def update_matches(t, i)
    m = t.matches[i]

    ag = AssignGoals.new

    team1_id = ag.team_1_id(m)
    team2_id = ag.team_2_id(m)

    player1_list = ag.get_player_list(team1_id)
    player2_list = ag.get_player_list(team2_id)

    scores = sim_playoff_series(m) # defined in sim_series
    m.scores_csv = scores.join(",")

    # assign team 1 players some goals
    ag.assign_goals(scores, team1_id, team1_id, player1_list)
    # assign team 2 players some goals
    ag.assign_goals(scores, team2_id, team1_id, player2_list)

    player1_list.each { |p| p.save}
    player2_list.each { |p| p.save}

    m
end

def team_series_data(series_range,t)
    teams = []
    team_1 = t.matches.collect{|p| p.player1.name}[series_range]
    team_2 = t.matches.collect{|p| p.player1.name}[series_range]
    teams << [team_1, team_2].flatten
    teams.flatten
end

def make_team_table(answer)
    team = Team.all.find_by(name: answer)
    puts team.img_path
    rows = []
    rows << [team.name, team.wins, team.losses, team.games_played, team.championship_wins]
    table = Terminal::Table.new :headings => ["Name", "Wins", "Losses", "Games Played", "Championship Wins"], :rows => rows 
    puts table
end

def make_player_table(answer)
    team = Team.all.find_by(name: answer)
    puts team.img_path
    players = Player.all.select { |p| p.team_id == team.id}
    rows = []
    players.each { |e| rows << [e.name, e.series_goals, e.total_goals]} # add goals per game
    table = Terminal::Table.new :headings => ["Name", "Series Goals", "Total Goals"], :rows => rows 
    puts table
end

binding.pry
# answer = "Washington Capitals"
# first round
for i in 0..7
    update_matches(t,i).save
end

live_url = "https://challonge.com/" + t.url + "/fullscreen"
Launchy::Browser.run(live_url)


prompt = TTY::Prompt.new
answer = prompt.select("First Round Complete:") do |menu|
    menu.choice "Team Stats", 1
    menu.choice "Player Stats", 2
    menu.choice "Simulate Second Round", 3
end
if answer == 1
    list = team_series_data(0..7,t)
    prompt = TTY::Prompt.new
    answer = prompt.select("Select Team:", list)
    make_team_table(answer)
elsif answer == 2
    list = team_series_data(0..7,t)
    prompt = TTY::Prompt.new
    answer = prompt.select("Players from:", list)
    make_player_table(answer)
# Second round
elsif answer == 3
        for i in 8..11
            update_matches(t,i).save
    end
end


prompt = TTY::Prompt.new
answer = prompt.select("Second Round Complete:") do |menu|
    menu.choice "Team Stats", 1
    menu.choice "Player Stats", 2
    menu.choice "Simulate Conference Finals", 3
end
if answer == 1
list = team_series_data(8..11,t)
    prompt = TTY::Prompt.new
    answer = prompt.select("Select Team:", list)
    make_team_table(answer)
elsif answer == 2
    list = team_series_data(8..11,t)
    prompt = TTY::Prompt.new
    answer = prompt.select("Players from:", list)
    make_player_table(answer)
elsif answer == 3
    for i in 12..13
        update_matches(t,i).save
    end
end

# Conference finals
prompt = TTY::Prompt.new
answer = prompt.select("Conference Finals Complete:") do |menu|
    menu.choice "Team Stats", 1
    menu.choice "Player Stats", 2
    menu.choice "Simulate Stanley Cup Final", 3
end
if answer == 1
    list = team_series_data(12..13,t)
        prompt = TTY::Prompt.new
        answer = prompt.select("Select Team:", list)
        make_team_table(answer)
    elsif answer == 2
        list = team_series_data(12..13,t)
        prompt = TTY::Prompt.new
        answer = prompt.select("Players from:", list)
        make_player_table(answer)
    elsif answer == 3
    update_matches(t,14).save
end
#  Stanley Cup finals
# Submit full tournament
t.post(:finalize)

def roll_credits
    puts "ROll CREDITS"
end 

prompt = TTY::Prompt.new
answer = prompt.select("Conference Finals Complete:") do |menu|
    menu.choice "Team Stats", 1
    menu.choice "Player Stats", 2
    menu.choice "Exit", 3
end
if answer == 1
    list = team_series_data(14,t)
        prompt = TTY::Prompt.new
        answer = prompt.select("Select Team:", list)
        make_team_table(answer)
    elsif answer == 2
        list = team_series_data(14,t)
        prompt = TTY::Prompt.new
        answer = prompt.select("Players from:", list)
        make_player_table(answer)
    elsif answer == 3
        roll_credits
    end
# t.live_image_url
# if t.matches(:first).player1_id == t.matches(:first).winner_id 
#     puts "want them chips with the dip" 
# else
#     puts "unfortunately you lost"
# end

