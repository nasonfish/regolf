#!/usr/bin/perl

use warnings;
use strict;
package Regolf;
use base qw(Bot::BasicBot);
use Bot::BasicBot;
use List::Util qw( shuffle );

my $wordlist = '/usr/share/dict/words'; # This is our big dictionary of words to pick from. ideally we will make the words similar in some way.

my @good = ();
my @bad = ();  # two lists

my $usefilters = 0;
my @filters = ();
if($usefilters){
  @filters = ('(\w{3}).*\1', '^_0.*_0$', '^[qwertyuiopasdfghjkl]+$', '^[a-f]+$', '=', '_0_1_2', '^(.)(.)(.?)(.?)(.?)(.?).?\6\5\4\3\2\1$');
} else {
  @filters = ('.');
}
my @characters = ("a".."z");
my $hurryup = 0; # we set two timers, one for the hurry up message, so this flicks back and forth between 0 and 1 depending on if we're waiting to end the round (1) or not (0)

my @admins = ();
open my $a_file, '<', 'admins.txt';
while(my $admin = <$a_file>){
  chomp($admin);
  push @admins, $admin;
}
close $a_file;
sub wordset {
  my ($self, $amt) = @_;
  my @words = ();
  while(@words <= ($amt * 2)){
    @words = ();
    my $f = $filters[rand @filters];
    if( $f eq "="){
      my $num = int(rand(7)+2);
      print STDOUT $num;
      for my $n(1000..100000){
        push @words, $n if $n % $num == 0;
      }
    } else {
      for my $j (0..9) {
        my $letter = $characters[rand @characters];
        $f =~ s/_$j/$letter/g;
      }
      print STDOUT "$f\n";
      open WORDS, '<', $wordlist or die "Cannot open $wordlist:$!";
      while(my $word = <WORDS>){
        chomp($word);
        push @words, $word if $word =~ /^[a-z]{2,}$/i and $word =~ /$f/i;  # filter out names with capitol letters as well as apostrophes and stuff; apply a certain filter
      }
      close WORDS;
    }
  }
  return @words;
}
sub wordgen {
  my $self = shift;
  print STDOUT "Generating words.\n";
  my $amt = int(rand(5)+3); # from 3-8 words
  if(int(rand(15)) == 10 && $usefilters){
    print STDOUT "Special round! Using two different sets this time.";
    my @words = $self->wordset($amt);
    @words = shuffle(@words);
    @good = @words[0 .. ($amt-1)]; # get the first <x> words
    @words = $self->wordset($amt);
    @words = shuffle(@words);
    @bad = @words[0 .. ($amt-1)];
    for my $bd (@bad){
      @good = grep {$_ ne $bd} @good;
    }
  } else {
    my @words = $self->wordset($amt * 2);
    @words = shuffle(@words);
    @good = @words[0 .. ($amt - 1)];
    @bad = @words[$amt .. (($amt * 2) - 1)];
  }
}


my $channel = "#regolf";
my $nick = "regolf";
my $playing = 0;

my $points = 0;

my %roundscores = ();  # hashes
my %gamescores = ();
my %roundexps = ();

sub scores{
  my $self = shift;
  my $scorestr = "";
  for my $key(keys %gamescores){
    $scorestr .= "\x0310$key: \x0307$gamescores{$key}, ";
  }
  $scorestr =~ s/..$//;
  $scorestr =~ s/^$/No scores have been recorded yet./;
  $self->say(channel => $channel, body => "\x0312$scorestr\x0f");
  print STDOUT $scorestr; 
}

sub said{
  my($self, $message) = @_;  # the arguments of this function include the self object and the message, which contains all the information we need about the event.
  print STDOUT $message;
  if($message->{channel} eq $channel and not $playing and $message->{body} =~ /^!start(?: !T ([a-zA-Z-]+))?$/){  # channel is correct, we're not already playing, the message starts with !start
    $playing = 1;
    if($1){
      $wordlist = "/usr/share/dict/" . $1;
    }
    $self->say(channel => $channel, body => "Beginning new regex golf game.");
    $self->newRound();
  } elsif($message->{channel} eq $channel and $playing and $message->{body} =~ /^!pause/){
    $playing = 0;
    $self->say(channel => $channel, body => "Pausing current regex golf game.");
  } elsif($message->{channel} eq $channel and $playing and $message->{body} =~ /^!haltround/ and $message->{who} ~~ @admins){
    $hurryup = 1;
    $self->schedule_tick(1);
  } elsif($message->{channel} eq $channel and $playing and $message->{body} =~ /^!scores/){
    $self->scores();
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
    $self->notice(who => $message->{who}, channel=>"msg", body=>"$message->{body} ($score): $msg"); # who is the name of the person while channel is "msg" for pms
    
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
  $self->say(who => "NickServ", channel => "msg", "body" => "IDENTIFY regolf $pwd");  # once we're connected we identify with chanserv with the password in pwd.txt
  close $file;
}

sub newRound{
  my $self = shift;
  if(not $playing){
    return;
  }
  $self->wordgen();
  %roundscores = ();
  %roundexps = ();
  $points = length(join("", @good) . join("", @bad));
  $points = $points < 40 ? 40 : $points;
  $self->say(channel => $channel, body => "\x0305Please match: \x02\x0303" . join(", ", @good) . "\x0f\x02");  # . concatenates, join joins it as an array spliced together with ", "
  $self->say(channel => $channel, body => "\x0305Do not match: \x0304\x02" . join(", ", @bad) . "\x0f\x02");
  my $time = int(80 + (.25 * $points));
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
    $self->scores();
    $self->checkwin();
    $self->newRound();
  }
}

sub checkwin{
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
    $self->say(channel=>$channel, body=>"Seems we have \x02a tie!\x02 Let's play until the tie is broken.");
    return undef;
  }
  if($winner){
    %gamescores = ();
    $self->say(channel=>$channel, body=>"We have a winner! Congratulations to \x02$winner\x02, for winning with \x02$winscore\x02 points!");
    $playing = 0;
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
  flood => 1  # disables flood protection, that sends a message every 3 seconds instead of bursting. this should be required, I'll look into making this work well but work quicker.
)->run(); # go!
