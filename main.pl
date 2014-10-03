#!/usr/bin/perl

use warnings;
use strict;
package Regolf;
use base qw(Bot::BasicBot);

use Bot::BasicBot;
use List::Util qw( shuffle );

my $wordlist = '/usr/share/dict/words'; # This is our big dictionary of words to pick from. ideally we will make the words similar in some way.
my @words = ();

my @filters = ('(\w{3})\1');

open WORDS, '<', $wordlist or die "Cannot open $wordlist:$!";
while(my $word = <WORDS>){
  chomp($word);
  my $f = $filters[rand @filters];
  push @words, $word if $word =~ /^[a-z]+$/ and $word =~ /$f/;  # filter out names with capitol letters as well as apostrophes and stuff; apply a certain filter
}
close WORDS;


my $channel = "#regolf";
my $playing = 0;

my $points = 0;
my @good = ();
my @bad = ();  # two lists

my %roundscores = ();  # hashes
my %gamescores = ();
my %roundexps = ();

sub said{
  my($self, $message) = @_;  # the arguments of this function include the self object and the message, which contains all the information we need about the event.
  if($message->{channel} eq $channel and not $playing and $message->{body} =~ /^!start/){  # channel is correct, we're not already playing, the message starts with !start
    $playing = 1;
    $self->say(channel => $channel, body => "Beginning new regex golf game.");
    $self->newRound();
  } elsif($message->{channel} eq $channel and $playing and $message->{body} =~ /^!pause/){
    $playing = 0;
    $self->say(channel => $channel, body => "Pausing current regex golf game.")
  } elsif($message->{channel} eq "msg" and $playing == 1){  # in pm, we /are/ playing
    my $score = $points;
    my @goodmiss = ();
    my @badmiss = ();
    foreach my $i (@good){
      if($i !~ /$message->{body}/){
        $score -= length($i);
        push @goodmiss, $i;
      }
    }
    foreach my $i (@bad){
      if($i =~ /$message->{body}/){
        $score -= length($i);
        push @badmiss, $i;
      }
    }
    $score -= length($message->{body});
    $score = $score < 0 ? 0 : $score;
    $self->say(who => $message->{who}, channel=>"msg", body=>"$message->{body} " . (length(@goodmiss) == 0 ? "matches all positive strings" : "does not match " . join(", ", @goodmiss)) . (length(@badmiss) == 0 ? " and does not match any negative strings." : " and does match " . join(",", @badmiss))); # who is the name of the person while channel is "msg" for pms
    $roundexps{ $message->{who} } = $message->{body};
    $roundscores{ $message->{who} } = $score;
  }
}

sub connected{
  my $self = shift;
  open my $file, '<', 'pwd.txt';
  my $pwd = <$file>;
  chomp($pwd);
  $self->say(who => "NickServ", channel => "msg", "body" => "IDENTIFY regolf $pwd");  # once we're connected we identify with chanserv with the password in pwd.txt
}

sub newRound{
  my $self = shift; # first argument, since we call $self->...
  my @t_words = shuffle(@words);  # our word list we collected earlier contains the words. shuffled with List::Util
  my $amt = int(rand(7)+3); # from 3-9 words
  @good = @t_words[0 .. $amt]; # get the first <x> words
  @bad = @t_words[($amt+1) .. (($amt*2)+1)];  # and the second <x> words, so there's an equal amount.
  $points = length(join("", @good)) * 2;
  $self->say(channel => $channel, body => "Please match: " . join(", ", @good));  # . concatenates, join joins it as an array spliced together with ", "
  $self->say(channel => $channel, body => "Do not match: " . join(", ", @bad));
  $self->say(channel => $channel, body => "You have 120 seconds; Private message me your regular expression using \x02/msg regolf expression\x02!");
  $self->schedule_tick(120);  # sixty seconds later, we call tick{}. this was actually called five seconds after the bot started, but that should have been ignored. (TODO make that better, if the game starts too soon.)
}

sub tick{
  my $self = shift;  # first arg is self
  if($playing){  # we are playing a game, otherwise this was errant, like in the first 5 seconds of the bot running.
    foreach my $i (keys %roundexps){
      $self->say(channel=>$channel, body=>"User $i submitted /$roundexps{$i}/ - worth $roundscores{$i} points.");  # just return nick: regex  into the channel.
    }
    $self->newRound();
  }
}

my $bot = Regolf->new(
  server => "irc.esper.net",  # pool
  port => 6697,  # ssl port
  ssl => 1,  # true-y value
  channels => [$channel],  # the channel was specified at the top of the file
  nick => "regolf",
  username => "regolf",
  name => "Perl Regex Golf IRC Bot",  # todo either ctcp the link to the source or put it here
  flood => 1  # disables flood protection, that sends a message every 3 seconds instead of bursting. this should be required, I'll look into making this work well but work quicker.
)->run(); # go!

