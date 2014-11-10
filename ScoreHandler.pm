#!/usr/bin/perl

package RegolfDB;
use strict;
use warnings;
require Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( score_check score_out %roundscores %gamescores %roundexps $points );

our $points = 0;

my %roundscores = ();  # hashes
my %gamescores = ();
my %roundexps = ();

sub score_out{
  my $self = shift;
  my $scorestr = "";
  for my $key(keys %gamescores){
    $scorestr .= "\x0310$key: \x0307$gamescores{$key}, ";
  }
  $scorestr =~ s/..$//;
  $scorestr =~ s/^$/No scores have been recorded yet./;
  $self->say(channel => $self->channel, body => "\x0312$scorestr\x0f");
  print STDOUT $scorestr; 
}


sub score_check{
  my $self = shift;
  my $winner = 0;
  my $winscore = 0;
  my $tie = 0;
  foreach my $key (keys %gamescores){
    if($gamescores{ $key } >= 100){
      if($gamescores{ $key } > $winscore){
        $winscore = $gamescores{ $key };
        $winner = $key;
        $tie = 0;
      } elsif($gamescores{$key} == $winscore){
        $tie = 1;
      }
    }
  }
  if($tie){
    $self->say(channel=>$self->channel, body=>"Seems we have \x02a tie!\x02 Let's play until the tie is broken.");
    return 1;
  }
  if($winner){
    db_game_end(\%gamescores, $winner);
    %gamescores = ();
    $self->say(channel=>$self->channel, body=>"We have a winner! Congratulations to \x02$winner\x02, for winning with \x02$winscore\x02 points!");
    return 0;
  }
  return 1;
}

1;