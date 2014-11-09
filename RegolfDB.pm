#!/usr/bin/perl

package RegolfDB;
use strict;
use warnings;
use DBI;
require Exporter;

our @ISA = qw( Exporter );
our @EXPORT_OK = qw( db_init db_game_init db_round_init db_round_end db_game_end db_user_stats );
our @EXPORT = qw( db_init db_game_init db_round_init db_round_end db_game_end db_user_stats );

our $db = DBI->connect("dbi:SQLite:dbname=data.db","","") or die $DBI::errstr;
our $gameid = undef;
our $roundid = undef;

sub db_init {
  my $stmnt = $db->do("CREATE TABLE IF NOT EXISTS games (id INTEGER PRIMARY KEY, ts INTEGER, winner VARCHAR(64))");
  $stmnt = $db->do("CREATE TABLE IF NOT EXISTS game_scores (id INTEGER PRIMARY KEY, game_id INTEGER, user VARCHAR(64), score INTEGER, FOREIGN KEY(game_id) REFERENCES games(id))");
  $stmnt = $db->do("CREATE TABLE IF NOT EXISTS round (id INTEGER PRIMARY KEY, game_id INTEGER, regex VARCHAR(128), FOREIGN KEY(game_id) REFERENCES games(id))");
  $stmnt = $db->do("CREATE TABLE IF NOT EXISTS round_words (id INTEGER PRIMARY KEY, round_id INTEGER, word VARCHAR(64), good BOOLEAN, FOREIGN KEY(round_id) REFERENCES round(id))");
  $stmnt = $db->do("CREATE TABLE IF NOT EXISTS round_submissions (id INTEGER PRIMARY KEY, round_id INTEGER, regex VARCHAR(128), user VARCHAR(64), score INTEGER, FOREIGN KEY(round_id) REFERENCES round(id))")
}

sub db_game_init {
  db_init();
  $db->do("INSERT INTO games (ts) VALUES (strftime('%s', 'now'))");
  $gameid = $db->last_insert_id("","","games","");
  print STDOUT "Last insert id is $gameid.\n";
}

sub db_round_init {
  my $regex = $_[0];
  my @good = @{$_[1]};
  my @bad = @{$_[2]};
  $db->prepare("INSERT INTO round (game_id, regex) VALUES (?, ?)")->execute($gameid, $regex);
  $roundid = $db->last_insert_id("","","round","");
  foreach my $i (@good){
    $db->prepare("INSERT INTO round_words (round_id, word, good) VALUES (?, ?, 1)")->execute($roundid, $i);
  }
  foreach my $i (@bad){
    $db->prepare("INSERT INTO round_words (round_id, word, good) VALUES (?, ?, 0)")->execute($roundid, $i);
  }
}

sub db_round_end {
  my %roundscores = %{$_[0]};
  my %roundexps = %{$_[1]};
  foreach my $i (keys %roundexps){
    $db->prepare("INSERT INTO round_submissions (round_id, regex, user, score) VALUES (?, ?, ?, ?)")->execute($roundid, $roundexps{ $i }, $i, $roundscores{ $i });
  }
}

sub db_game_end {
  my %gamescores = %{$_[0]};
  my $winner = $_[1];
  $db->prepare("UPDATE games SET winner=? WHERE id=?")->execute($winner, $gameid);
  foreach my $i (keys %gamescores){
    $db->prepare("INSERT INTO game_scores (game_id, user, score) VALUES (?, ?, ?)")->execute($gameid, $i, $gamescores{ $i });
  }
}

sub db_user_stats {
  my $user = $_[0];
  $stmt = $db->prepare("SELECT MIN(score), MAX(score), AVG(score), COUNT(winner), (COUNT(user)-COUNT(winner)) FROM game_scores WHERE user=? LEFT JOIN games ON game_scores.id = games.id")->execute($user);
  #my ($min, $max, $avg, $wins, $losses) = $stmt->fetchrow_array;
  return $stmt->fetchrow_array;
}
1;
