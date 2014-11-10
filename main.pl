#!/usr/bin/perl

use warnings;
use strict;
package Regolf;
use base qw(Bot::BasicBot);
use Bot::BasicBot;
use List::Util qw( shuffle );
use RegolfDB qw( db_init db_game_init db_round_init db_round_end db_game_end db_user_stats );
use WordGenerator qw( word_grab word_generate @good @bad );
our (@good, @bad, $wordlist, $roundwordlist);
use ScoreHandler qw( score_check score_out %roundscores %gamescores %roundexps );
our (%roundscores, %gamescores, %roundexps, $points);

my $hurryup = 0; # we set two timers, one for the hurry up message, so this flicks back and forth between 0 and 1 depending on if we're waiting to end the round (1) or not (0)

my @admins = ();
open my $a_file, '<', 'admins.txt';
while(my $admin = <$a_file>){
  chomp($admin);
  push @admins, $admin;
}
close $a_file;

my $channel = "#regolf";
my $nick = "regolf";
my $playing = 0;

sub said{
  my($self, $message) = @_;  # the arguments of this function include the self object and the message, which contains all the information we need about the event.
  print STDOUT $message;
  if($message->{channel} eq $channel and not $playing and $message->{body} =~ /^!start(?: !L ([a-zA-Z-]+))?$/){  # channel is correct, we're not already playing, the message starts with !start
    if($1){
      $roundwordlist = "/usr/share/dict/" . $1;
    } else {
      $roundwordlist = $wordlist;
    }
    if (not -e $roundwordlist){
      $self->say(channel => $channel, body => "\x0304Error:\x0f The selected wordlist does not exist - contact bot admin for supported dictionaries.")
    } else {
      $playing = 1;
      $self->say(channel => $channel, body => "Beginning new regex golf game.");
      db_game_init();
      $self->newRound();
    }
  } elsif($message->{channel} eq $channel and $playing and $message->{body} =~ /^!pause/){
    $playing = 0;
    $self->say(channel => $channel, body => "Pausing current regex golf game.");
  } elsif($message->{channel} eq $channel and $playing and $message->{body} =~ /^!haltround/ and $message->{who} ~~ @admins){
    $hurryup = 1;
    $self->schedule_tick(1);
  } elsif($message->{channel} eq $channel and $playing and $message->{body} =~ /^!scores/){
    score_out($self);
  } elsif($message->{body} =~ /^!stats(?: ([^ ]+))?$/ and $message->{channel} eq $channel){
    my $user = $message->{who};
    $user = $1 if $1;
    my ($min, $max, $avg, $wins, $losses) = db_user_stats($user);
    if(not defined $min){
      $self->say(channel => $channel, body => "$user does not have any records saved in our database.");
    } else {
      $self->say(channel => $channel, body => "$user stats: Scores between $min and $max averaging $avg - $wins wins and $losses losses.");
    }
  } elsif($message->{body} =~ /^!key/){
    $self->say(channel => $channel, body => "r(e)?ge[x] (score/\x033good hit amount\x0f/\x034bad miss amount\x0f): Positive: \x033hit\x0f, \x033words\x0f, \x0314missed\x0f, \x0314words\x0f | Negative: \x0314missed\x0f, \x0314words\x0f, \x034hit\x0f, \x034words\x0f");
  } elsif($message->{channel} eq "msg" and $playing == 1 and $message->{who} !~ /Serv$/){  # in pm, we /are/ playing, it's not a service
    my $score = $points;
    my @goodmiss = ();
    my @badmiss = ();
    $message->{body} =~ s/\(\?R\)|\\p//g;
    print STDOUT "Recieved $message->{body} by $message->{who}.\n";
    my $valid = eval { qr/$message->{body}/ };
    if($@){
      $@ =~ s/;.*$|[\r\n]//g;
      $self->notice(who => $message->{who}, channel=>"msg", body => "This regular expression is invalid - $@");
      return undef;
    }
    my $msg = "Positive: ";
    foreach my $i (@good){
      if($i !~ /$message->{body}/){
        push @goodmiss, $i;
        print STDOUT "Missed $i\n";
        $msg .= "\x0314$i\x0f, ";
      } else { $msg .= "\x0303$i\x0f, "; }
    }
    $msg =~ s/..$/ | Negative: /;
    foreach my $i (@bad){
      if($i =~ /$message->{body}/){
        push @badmiss, $i;
        print STDOUT "Hit $i\n";
        $msg .= "\x0304$i\x0f, ";
      } else { $msg .= "\x0314$i\x0f, "; }
    }
    $score *= 1.5**(-(@goodmiss + @badmiss));
    $score -= 3 * length($message->{body});
    $score = $score < 0 ? 0 : int($score);
    if(@good == @goodmiss || @bad == @badmiss){
      $score = 0;
    }
    $msg =~ s/..$//;
    $self->notice(who => $message->{who}, channel=>"msg", body=>"$message->{body} ($score/\x0303" . (@good - @goodmiss) . "\x0f/\x0304" . (@bad - @badmiss) . "\x0f): $msg"); # who is the name of the person while channel is "msg" for pms
    
    if(!exists $roundscores{$message->{who}} or $roundscores{$message->{who}} <= $score){
      $roundexps{ $message->{who} } = $message->{body};
      $roundscores{ $message->{who} } = $score;
    }
  }
  return undef;
}

sub connected{
  my $self = shift;
  open my $file, '<', 'pwd.txt';
  my $pwd = <$file>;
  chomp($pwd);
  $self->say(who => "NickServ", channel => "msg", "body" => "IDENTIFY regolf $pwd");  # once we're connected we identify with NickServ with the password in pwd.txt
  close $file;
}

sub newRound{
  my $self = shift;
  if(not $playing){
    return;
  }
  word_generate();
  %roundscores = ();
  %roundexps = ();
  $points = length(join("", @good) . join("", @bad));
  $points = $points < 40 ? 40 : $points;
  $self->say(channel => $channel, body => "\x0305Please match: \x02\x0303" . join(", ", @good) . "\x0f\x02");  # . concatenates, join joins it as an array spliced together with ", "
  $self->say(channel => $channel, body => "\x0305Do not match: \x0304\x02" . join(", ", @bad) . "\x0f\x02");
  my $time = int(20 + (.37 * $points));
  $self->say(channel => $channel, body => "You have $time seconds; Private message me your regular expression(s) using \x02/msg $nick expression\x02!");
  $hurryup = 0;
  $self->schedule_tick($time - 15);
}

sub tick{
  my $self = shift;  # first arg is self
  if($playing){  # we are playing a game, otherwise this was errant, like in the first 5 seconds of the bot running.
    if(!$hurryup){
      $self->say(channel=>$channel, body=>"Hurry up! You only have 15 seconds left to finish your expression!");
      $hurryup = 1;
      $self->schedule_tick(15);
      return undef;
    }
    if(!%roundexps){
      $self->say(channel=>$channel, body=>"No users submitted regular expressions! Pausing game - use \x02!start\x02 to resume.");
      $playing = 0;
    }
    foreach my $i (keys %roundexps){
      $self->say(channel=>$channel, body=>"User $i submitted \x02$roundexps{$i}\x02 - worth \x02$roundscores{$i}\x02 points.");  # just return nick: regex  into the channel.
      if(!exists $gamescores{$i}){
        $gamescores{ $i } = $roundscores{$i};
      } else {
        $gamescores{ $i } += $roundscores{$i};
      }
    }
    db_round_end(\%roundscores, \%roundexps);
    score_out($self);
    $playing = score_check($self);
    $self->newRound();
  }
}

my $bot = Regolf->new(
  server => "irc.esper.net",  # pool
  port => 6697,  # ssl port
  ssl => 1,  # true-y value
  channels => [$channel],  # the channel was specified at the top of the file
  nick => $nick, # the name the bot should use specified at the top of the file
  username => "regolf",
  name => "Perl Regex Golf IRC Bot",  # todo either ctcp the link to the source or put it here
  flood => 1,  # disables flood protection, that sends a message every 3 seconds instead of bursting. this should be required, I'll look into making this work well but work quicker.
  localaddr => "2604:a880:800:10::1c0:b001"
)->run(); # go!
