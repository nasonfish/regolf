#!/usr/bin/perl

use warnings;
use strict;
package Regolf;
use base qw(Bot::BasicBot);

use Bot::BasicBot;
use List::Util qw( shuffle );

my $wordlist = '/usr/share/dict/words';
my @words = ();
open WORDS, '<', $wordlist or die "Cannot open $wordlist:$!";
while(my $word = <WORDS>){
  chomp($word);
  push @words, $word if $word =~ /^[a-z]+$/;
}
close WORDS;


my $channel = "#regolf";
my $playing = 0;


my @good = ();
my @bad = ();

my %msgs = ();

sub said{
  my($self, $message) = @_;
  if($message->{channel} eq $channel and not $playing and $message->{body} =~ /^!start/){
    $playing = 1;
    $self->say(channel => $channel, body => "Beginning new regex golf game.");
    $self->newRound();
  } elsif($message->{channel} =~ /^[^#]/ and $playing == 1){
    $self->say(who => $message->{channel}, channel=>"msg", body=>"Recieved your result!");
    $msgs{ $message->{channel} } = $message;
  }
}

sub connected{
  my $self = shift;
  $self->say(who => "NickServ", channel => "msg", "body" => "IDENTIFY regolf thisismypasswordprobably");
}

sub newRound{
  my $self = shift;
  my @t_words = shuffle(@words);
  my $amt = int(rand(7));
  @good = @t_words[0 .. $amt];
  @bad = @t_words[($amt+1) .. (($amt*2)+1)];
  $self->say(channel => $channel, body => "Please match: " . join(", ", @good));
  $self->say(channel => $channel, body => "Do not match: " . join(", ", @bad));
  $self->say(channel => $channel, body => "You have 60 seconds.");
  $self->schedule_tick(60);
}

sub tick{
  my $self = shift;
  if($playing){
    $self->say(channel=>$channel, body=>"done!");
    foreach my $i (keys %msgs){
      $self->say(channel=>$channel, body=>"$i: $msgs{$i}");
    }
  }
}

sub endRound{
  
}

my $bot = Regolf->new(
  server => "irc.esper.net",
  port => 6697,
  ssl => 1,
  channels => [$channel],
  nick => "regolf",
  username => "regolf",
  name => "Perl Regex Golf IRC Bot",
  flood => 1
)->run();
